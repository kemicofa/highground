local test, new, check = ...
local function equal(a,b,why) return check(a,b,why or "values match") end
local function click(b) assert(b:IsVisible() and b:IsEnabled(), 'visible enabled action'); b:Click() end
local function open(s) s.ns.Hub.Open('profiles'); return s.ns.Options.panel, s.ns.Options.Profiles, s.ns.Core end
local function create(s, name, source)
  local p = open(s); click(p.profileButtons.New)
  p.profileName:SetText(name)
  if source then p.source:SetValue(source) end
  click(p.profileButtons.Save)
  return p
end
local function row(rows, id)
  for _, r in ipairs(rows) do if r.id == id then return r end end
end
for _, client in ipairs({ 'cata', 'retail', 'forever' }) do
  local function make(saved, geometry)
    return new(client == 'cata' and 'cata' or 'retail', saved or {}, function(s, env)
      if client == 'forever' then env.GetBuildInfo = function() return '1.60.1', '70532', 'Oct 22 2026', 16001 end end
      if geometry then dofile('../../tools/wowsim/geometry.lua')(s) end
    end)
  end
  test(client .. ' a failing refresh or layout is recorded and the next one still runs', function()
    local s=make(); local p=open(s)
    for _, broken in ipairs({ 'assignments', 'footer' }) do
      local method = broken == 'assignments' and 'Refresh' or 'Layout'
      local original = p[broken][method]
      p[broken][method] = function() error(broken .. ' broke') end
      p.RefreshProfiles()
      local stats = s.ns.Util.GuardStats[broken == 'footer' and 'profiles layout' or 'profiles page']
      assert(stats and stats.lastError:find(broken .. ' broke', 1, true), 'the failure is recorded')
      s.ns.Util.ClearErrors()
      p[broken][method] = original
      click(p.profileButtons.New)
      assert(p.profileButtons.Save:IsShown(), 'the page refreshes again')
      p.profileName:SetText(string.rep('Long name ', 3)); p.LayoutProfiles()
      click(p.profileButtons.Copy)
    end
    s:assertHealthy()
  end)

  test(client .. ' creation previews a source against Default and offers complete contents explicitly', function()
    local s=make(); local p,P,C=open(s);local live=P.ExportString(P.Snapshot())
    click(p.profileButtons.New);p.source:SetValue('preset:healer')
    equal(row(p.reviewRows,'features.sniper').before,'On');equal(row(p.reviewRows,'features.sniper').text,'Off')
    assert(not row(p.reviewRows,'style.fontScale'),'unchanged settings are omitted')
    click(p.profileButtons.Details)
    assert(row(p.reviewRows,'style.fontScale') and row(p.reviewRows,'positions.point') and row(p.reviewRows,'points.killPer'))
    equal(P.ExportString(P.Snapshot()),live,'choosing a source never applies it')
    click(p.profileButtons.Copy);equal(P.ExportString(P.Snapshot()),live,'cancel preserves settings')
    create(s,'Healer BG','preset:healer')
    equal(C.db.activeProfile,'Healer BG');equal(C.db.sniper,false);assert(not P.ActiveState().modified)
    local count=#p.reviewRows;assert(count>0 and count<100)
    click(p.profileButtons.Details);assert(#p.reviewRows>100)
    click(p.profileButtons.Details);equal(#p.reviewRows,count)
    equal(C.db.profiles.Default.setup.features.sniper,true)
    s:assertHealthy()
  end)
  test(client .. ' comparisons stay anchored to Default across edits, updates, applying and navigation', function()
    local s=make();create(s,'My setup');local p,P,C=open(s)
    equal(#p.reviewRows,0)
    C.SetFeature('sniper',false);C.SetPanelScale('main',1.1);s.ns.Alerts.SetMode('objectives');s:advance(0.6)
    equal(#p.reviewRows,0,'browsing still describes the saved copy, not unrelated current settings')
    click(p.profileButtons.Update)
    assert(row(p.reviewRows,'features.sniper') and row(p.reviewRows,'style.scales.main') and row(p.reviewRows,'alerts.go.sound'))
    local count=#p.reviewRows;click(p.profileButtons.Save);equal(#p.reviewRows,count)
    equal(row(p.reviewRows,'features.sniper').before,'On');equal(row(p.reviewRows,'features.sniper').text,'Off')
    local expected=P.ReviewText(p.reviewRows)
    C.SetFeature('sniper',true);s:advance(1.1);equal(P.ReviewText(p.reviewRows),expected)
    click(p.profileButtons.Load);equal(C.db.sniper,false);equal(P.ReviewText(p.reviewRows),expected)
    for _=1,3 do
      p.SelectProfile('Default');assert(not p.profileScroll:IsShown() and #p.reviewRows==0)
      p.SelectProfile('My setup');click(p.profileButtons.Details);click(p.profileButtons.Details)
      click(p.profileButtons.Copy);click(p.profileButtons.Copy)
      s.ns.Hub.Open('home');s.ns.Hub.Open('profiles');s:advance(1)
      equal(P.ReviewText(p.reviewRows),expected,'buttons and show/idle transitions do not replace the comparison')
    end
    s:assertHealthy()
  end)
  test(client .. ' selection, copying, name collisions and deferred activation have explicit effects', function()
    local s=make(); create(s,'First'); local p,P,C=open(s)
    C.SetFeature('sniper',false); create(s,'Second')
    p.SelectProfile('First'); equal(C.db.sniper,false)
    click(p.profileButtons.Copy); p.profileName:SetText('Copy'); click(p.profileButtons.Save)
    equal(C.db.profiles.Copy.setup.features.sniper,true,'copy uses selected saved profile')
    click(p.profileButtons.New); p.profileName:SetText('Second'); click(p.profileButtons.Save)
    equal(C.db.profiles.Second.setup.features.sniper,false,'duplicate creation never overwrites')
    click(p.profileButtons.Copy); p.SelectProfile('Second')
    s:setCombat(true); click(p.profileButtons.Load)
    equal(C.db.activeProfile,'Copy'); equal(P.pending.profileName,'Second')
    s:setCombat(false); equal(C.db.activeProfile,'Second'); equal(C.db.sniper,false)
    assert(not P.DeleteProfile('Default')); s:assertHealthy()
  end)
  test(client .. ' inline activity choices survive switching off and cancel deleted pending assignments', function()
    local s=make(); create(s,'Arena'); local p,P,C=open(s)
    local a=p.assignments
    -- WoW Forever has no arenas, so no Arena activity.
    local activity=client=='forever' and 'bg' or 'arena'
    equal(a.activities.arena==nil,client=='forever','Arena activity only where the game has arenas')
    assert(a:IsVisible() and a.activities[activity]:IsVisible())
    a.activities[activity]:SetValue('Arena'); a.enabled:SetChecked(true)
    local who,key=P.Context(activity); equal(C.db.profileAssignments[who][key],'Arena')
    a.enabled:SetChecked(false); equal(C.db.profileAssignments[who][key],'Arena')
    p.SelectProfile('Default'); click(p.profileButtons.Load)
    s:setCombat(true); P.LoadProfile('Arena'); P.DeleteProfile('Arena')
    equal(P.pending,nil); equal(C.db.profileAssignments[who][key],nil)
    s:setCombat(false); equal(C.db.activeProfile,'Default'); s:assertHealthy()
  end)
  test(client .. ' profile controls and comparison rows fit both font scales and themes', function()
    local s=make({},true);create(s,'Healer with a longer profile name','preset:healer');local p,P,C=open(s)
    for _,scale in ipairs({1,1.5})do for _,theme in ipairs({'highground','parchment'})do
      s.ns.Theme.Use(theme);C.SetFontScale(scale);s:advance(1);p.RefreshProfiles()
      local function below(a,b)local x,y=s.bounds(a),s.bounds(b);assert(x[2]+x[4]<=y[2]+1,'vertical controls do not overlap')end
      local function left(a,b)local x,y=s.bounds(a),s.bounds(b);assert(x[1]+x[3]<=y[1]+1,'columns do not overlap')end
      left(p.assignments,p.detail);below(p.listScroll,p.profileButtons.New);below(p.profileButtons.New,p.assignments)
      below(p.actions,p.profileScroll);below(p.profileScroll,p.profileStatus);below(p.assignments,p.profileStatus);below(p.profileStatus,p.footer)
      assert(p.profileScroll:GetHeight()>180,'comparison has a readable viewport')
      assert(p.listScroll:GetHeight()>60,'profile selection remains usable at large text')
      local top=s.bounds(p.assignments)[2];p.profileScroll:Scroll(p.profileScroll.range)
      equal(s.bounds(p.assignments)[2],top,'switching remains visible while the review scrolls')
      click(p.profileButtons.New);left(p.profileName,p.source);below(p.profileName,p.actions)
      assert(p.profileScroll:GetHeight()>90,'creation leaves space for its comparison')
      click(p.profileButtons.Copy)
      for _,key in ipairs({'Load','Update','Copy','Import','Export','Chat','Delete'})do
        local b=p.profileButtons[key];assert(b.label:GetStringWidth()<=b:GetWidth()-12,key..' label fits')
      end
      s:assertHealthy()
    end end
  end)
  test(client .. ' deleting a profile needs a second click and cancels when the context changes', function()
    local s = make(); create(s, 'Spare'); create(s, 'Other')
    local p = open(s)
    local delete = p.profileButtons.Delete
    p.SelectProfile('Spare'); click(delete)
    assert(delete:IsArmed() and delete.text == 'Confirm delete', 'the first click asks for confirmation')
    assert(s.ns.Core.db.profiles.Spare and p.statusText:find('Confirm delete', 1, true), 'nothing is deleted yet')
    p.SelectProfile('Other')
    assert(not delete:IsArmed() and delete.text == 'Delete', 'selecting another profile cancels')
    equal(p.statusText, '', 'the stale prompt is cleared')
    p.SelectProfile('Spare'); click(delete); s.ns.Hub.win:Hide(); open(s)
    assert(not delete:IsArmed() and not p.statusText:find('Confirm delete', 1, true), 'leaving the page cancels')
    p.SelectProfile('Spare'); click(delete); click(delete)
    assert(not s.ns.Core.db.profiles.Spare and s.ns.Core.db.profiles.Other, 'the second click deletes only the selection')
    assert(p.statusText:find('Deleted', 1, true) and not delete:IsArmed(), 'deletion is reported')
    local count = 0
    for _, r in ipairs(p.profileRows) do if r:IsShown() then count = count + 1 end end
    equal(count, 2, 'the recycled list shows Default and the remaining copy')
    p.SelectProfile('Default')
    assert(not delete:IsShown() and not delete:IsArmed(), 'Default cannot be deleted')
    -- A command removing the armed profile moves the selection; the next click must not delete it.
    create(s, 'Spare'); create(s, 'Keep'); p = open(s)
    p.SelectProfile('Spare'); click(delete); assert(delete:IsArmed(), 'armed on Spare')
    s:command('profile delete Spare'); p.RefreshProfiles()
    assert(p.selected ~= 'Spare' and not delete:IsArmed(), 'losing the armed selection cancels the confirmation')
    local survivor = p.selected
    if delete:IsShown() and delete:IsEnabled() then click(delete) end
    assert(s.ns.Core.db.profiles[survivor] and not s.ns.Core.db.profiles.Spare, 'one click never deletes the new selection')
    s:assertHealthy()
  end)
  test(client .. ' transfer controls fit larger text and share either saved or current settings', function()
    local s=make({},true);create(s,'Saved');local p,P,C=open(s)
    C.SetFeature('sniper',false)
    for _,scale in ipairs({1,1.5})do
      C.SetFontScale(scale);P.ShowExport('Saved');local w=P.share
      equal(P.ParseString(w:GetText()).setup.features.sniper,true,'export starts with selected saved contents')
      w.exportSource:SetValue('current')
      equal(P.ParseString(w:GetText()).setup.features.sniper,false,'current export includes unsaved edits')
      local function left(a,b)local x,y=s.bounds(a),s.bounds(b);assert(x[1]+x[3]<=y[1],'footer controls do not overlap')end
      left(w.done,w.exportSource);left(w.exportSource,w.chat)
      assert(w.chat.label:GetStringWidth()<=w.chat:GetWidth()-12,'chat label fits')
      s.env.ChatFrame_OpenChat('');click(w.chat)
      local payload=assert(s.chatDraft:match('%[HGP:(.+)%]'))
      equal(P.Chat.Decode(payload).label,'Current setup','current settings can be drafted without saving')
      s.env.ChatFrame_OpenChat('');w.exportSource:SetValue('profile:Saved');click(w.chat)
      payload=assert(s.chatDraft:match('%[HGP:(.+)%]'))
      equal(P.Chat.Decode(payload).label,'Saved','named sharing uses the selected copy')
      equal(#s.chat,0,'sharing only prepares a draft')
      P.ShowImport();w.box:SetText(P.ExportString(P.Snapshot(),'Saved'))
      left(w.done,w.name);left(w.name,w.actions.save);left(w.actions.save,w.actions.apply)
      for _,button in ipairs({w.done,w.actions.save,w.actions.apply})do
        assert(button.label:GetStringWidth()<=button:GetWidth()-12,'import action label fits')
      end
      local review,status=s.bounds(w.review),s.bounds(w.status)
      assert(review[4]>80 and w.scroll:GetHeight()>32,'paste and review both have space')
      assert(review[2]+review[4]<=status[2],'review stays above the fixed status')
    end
    s:assertHealthy()
  end)
  test(client .. ' position comparisons keep the same Default values across themes, imports and shared profiles', function()
    local s=make({},true);local p,P,C=open(s)
    local after=P.Snapshot();after.setup.positions.point={'BOTTOMRIGHT','BOTTOM',-12.5,36}
    P.SaveProfile('Position review',after);C.pos.point={'TOPLEFT','CENTER',0,-27};p.SelectProfile('Position review')
    local position=row(p.reviewRows,'positions.point')
    equal(position.before,'Default position');assert(position.text:find('Offset: 12.5 left, 36 up',1,true))
    assert(not position.text:find('[\128-\255]'),'position separators remain supported')
    local expected=P.ReviewText(p.reviewRows)
    for _,theme in ipairs({'parchment','highground'})do
      s.ns.Theme.Use(theme);C.SetFontScale(1.5);s:advance(1)
      equal(row(p.reviewRows,'positions.point').before,'Default position')
      click(p.profileButtons.Load);equal(row(p.reviewRows,'positions.point').before,'Default position')
    end
    local function diff(area)
      local text=area.text:GetText()
      assert(text:find(s.ns.Theme.Hex('danger')..'  - Default position|r',1,true))
      assert(text:find(s.ns.Theme.Hex('success')..'  + Panel bottom right at screen bottom',1,true))
      assert(area.body:GetHeight()>=area.text:GetStringHeight(),'full multiline values fit the scroll body')
    end
    P.ShowImport();local w=P.share;w.box:SetText(P.ExportString(after,'Position review'));diff(w.review)
    click(w.actions.save);diff(w.review);click(w.actions.apply);diff(w.review)
    P.Chat.Review(P.ExportString(after,'Shared'),'Friend-Realm','Shared');local shared=P.Chat.win;diff(shared.review)
    click(shared.details);click(shared.details);diff(shared.review)
    shared.review:Hide();s.ns.Theme.Use('parchment');shared.review:Show();diff(shared.review)
    s:assertHealthy()
  end)
end

test('comparison columns localize long reordered values without mutating snapshots',function()
  local s=new('cata',{});local p,P,C=open(s)
  C.pos.point={'TOPLEFT','CENTER',12,-27};P.SaveProfile('Language review');p.SelectProfile('Language review')
  local original=P.ReviewText(p.reviewRows);local saved=P.ExportString(P.Snapshot())
  s.ns.Locale.catalogs.frFR = {}
  assert(s.ns.Locale:Register('frFR',{
    ['profiles.compare.default']='DÉFAUT', ['profiles.compare.profile']='PROFIL',
    ['profiles.position']='Écran {screenAnchor}, panneau {panelAnchor}\nDécalage vertical {vertical}; décalage horizontal {horizontal}',
    ['profiles.anchor.top_left']='en haut à gauche', ['profiles.anchor.center']='au centre',
    ['profiles.panel.enemies']='Position du panneau des ennemis',
  }))
  local frames=#s.frames;assert(s.ns.Localization.SetPreference('frFR'))
  local text=P.ReviewText(p.reviewRows)
  assert(text:find('Position du panneau des ennemis',1,true))
  assert(text:find('Écran au centre, panneau en haut à gauche',1,true))
  assert(text:find('vertical 27 down; décalage horizontal 12 right',1,true),'missing directions use English')
  equal(p.profileScroll.columns[2]:GetText(),'DÉFAUT');equal(P.ExportString(P.Snapshot()),saved)
  assert(s.ns.Localization.SetPreference('enGB'));equal(P.ReviewText(p.reviewRows),original)
  equal(#s.frames,frames,'language changes reuse comparison controls')
  for _,anchor in ipairs({'TOPLEFT','TOP','TOPRIGHT','LEFT','CENTER','RIGHT','BOTTOMLEFT','BOTTOM','BOTTOMRIGHT'})do
    local snap=P.Snapshot();snap.setup.positions.point={anchor,anchor,0,0}
    assert(not row(P.Review(snap),'positions.point').text:find('profiles.',1,true))
  end
  for _,r in ipairs(P.Review(P.EnsureDefault()))do
    local _,_,_,group=P.ReviewFields(r);assert(not group:find('profiles.',1,true),'all dynamic group labels resolve')
  end
  s:assertHealthy()
end)

test('Default migration preserves editable snapshots, collisions and all saved references',function()
  local s=new('cata',{});local P,C=s.ns.Options.Profiles,s.ns.Core
  local custom=P.Snapshot();custom.setup.features.sniper=false
  local backup=P.Snapshot();backup.points.killPer=0
  C.db.profiles={Default=custom,['Before role preset']=backup,['Previous Default']=P.Snapshot()}
  C.db.activeProfile='Default';C.db.profileDefaultVersion=1
  C.db.profileAssignments={Alice={['one:bg']='Default'},Bob={['two:arena']='Before role preset'}}
  P.MigrateDefault()
  equal(C.db.profiles['Previous Default (2)'],custom);equal(C.db.profiles['Previous setup'],backup)
  equal(C.db.activeProfile,'Previous Default (2)');equal(C.db.profileAssignments.Alice['one:bg'],'Previous Default (2)')
  equal(C.db.profileAssignments.Bob['two:arena'],'Previous setup')
  equal(P.ExportString(C.db.profiles.Default),P.ExportString(P.DefaultSnapshot()))
  local default=C.db.profiles.Default;P.MigrateDefault();equal(C.db.profiles.Default,default)
  assert(s.ns.Setup.Apply('healer'));assert(s.ns.Setup.Apply('damage'));equal(C.db.profiles.Default,default)
  s:assertHealthy()
end)
test('Default stays immutable through UI, API, command and clipboard save paths',function()
  local s=new('cata',{});local p,P,C=open(s);local original=P.ExportString(P.EnsureDefault())
  C.SetFeature('sniper',false);C.pos.point={'TOP','TOP',20,-50};p.RefreshProfiles()
  assert(not p.profileScroll:IsShown() and not p.profileButtons.Details:IsShown())
  assert(not p.profileButtons.Save:IsShown() and not p.profileButtons.Update:IsShown() and not p.profileButtons.Delete:IsShown())
  assert(not P.SaveProfile('Default'));assert(not P.SaveImported(P.ExportString(P.Snapshot()),'Default'))
  s:command('profile save Default');s:command('profile delete Default')
  equal(P.ExportString(P.EnsureDefault()),original);equal(C.db.sniper,false)
  P.ShowImport();P.share.box:SetText(P.ExportString(P.Snapshot(),'Default'))
  assert(not P.share.actions.save:IsEnabled());equal(P.ExportString(P.EnsureDefault()),original)
  P.share:Hide();s.ns.Hub.Open('profiles');p.SelectProfile('Default');click(p.profileButtons.Load)
  equal(C.db.sniper,true);equal(C.pos.point,nil);equal(#p.reviewRows,0)
  s:assertHealthy()
end)

test('confirming a profile saves exactly the reviewed candidate when live settings change between clicks',function()
  local s=new('cata',{});create(s,'Reviewed');local p,P,C=open(s)
  C.SetFeature('sniper',false);click(p.profileButtons.Update)
  equal(row(p.reviewRows,'features.sniper').text,'Off')
  C.SetFeature('sniper',true)
  click(p.profileButtons.Save)
  equal(C.db.profiles.Reviewed.setup.features.sniper,false,'the confirmed copy matches the review')
  equal(C.db.sniper,true,'saving does not replace a newer live edit')
  assert(P.ActiveState().modified)
  click(p.profileButtons.New);local candidate=P.ExportString(p.reviewCandidate)
  C.SetFeature('sniper',false);p.profileName:SetText('Captured');click(p.profileButtons.Save)
  equal(P.ExportString(C.db.profiles.Captured),candidate,'creation also saves the reviewed candidate')
  s:assertHealthy()
end)

test('reviews normalize defaults, zero, false, layout, coordinates and partial profiles', function()
  local s=new('cata',{});local P,C=s.ns.Options.Profiles,s.ns.Core
  local old=P.Snapshot();local next=P.Snapshot()
  next.setup.style.scales={main=1};next.setup.style.layouts={arena=false,nearby=false}
  next.setup.alerts.channels.capture={text=true,sound=true}
  equal(#P.Review(next,old),0,'explicit defaults are not changes')
  next.points.killPer=0;next.setup.features.sniper=false
  next.setup.positions.point={'TOP','CENTER',0,-27};next.setup.disabledCooldowns[2139]=true
  local rows=P.Review(next,old)
  equal(row(rows,'points.killPer').text,'0');equal(row(rows,'features.sniper').text,'Off')
  assert(row(rows,'positions.point').text:find('Offset: 0 horizontal, 27 down',1,true));equal(row(rows,'cooldowns.2139').text,'Off')
  local legacy=P.Snapshot();legacy.setup=nil
  for _,r in ipairs(P.Review(legacy,next))do assert(not r.id:match('^style%.') and not r.id:match('^features%.'),'legacy scope')end
  local partial=P.Snapshot();partial.setup.preferences.reducedMotion=nil;partial.setup.preferences.locked=nil
  assert(not row(P.Review(partial),'preferences.reducedMotion') and not row(P.Review(partial),'preferences.locked'),
    'missing optional preferences are left alone, not reported as Off')
  local included=P.Snapshot();included.setup.preferences.reducedMotion=true
  local added=row(P.Review(included,partial),'preferences.reducedMotion')
  local addedText=P.ReviewText({added})
  assert(added.added and addedText:find('  + On',1,true) and not addedText:find('  - Not included',1,true),
    'a newly included setting has only an added value')
  local reset=row(P.Review(old,next),'positions.point')
  assert(P.ReviewText({reset}):find('  + Default position',1,true),'clearing a stored anchor explicitly restores the default')
  next.setup.style.loop=next.setup.style;assert(not P.Review(next,old),'malformed snapshots rejected')
end)
test('clipboard imports review updates and applications before action and keep saved receipts', function()
  local s=new('cata',{});create(s,'Saved');local p,P,C=open(s)
  local snap=P.Snapshot();snap.setup.features.sniper=false
  P.ShowImport();local w=P.share;w.box:SetText(P.ExportString(snap,'Saved'))
  local removed, added = s.ns.Theme.Hex('danger') .. '  - On|r', s.ns.Theme.Hex('success') .. '  + Off|r'
  assert(w.review.text:GetText():find(removed .. '\n' .. added,1,true),'old and new values have distinct diff lines before saving')
  equal(C.db.profiles.Saved.setup.features.sniper,true)
  click(w.actions.save);equal(C.db.profiles.Saved.setup.features.sniper,false)
  equal(C.db.sniper,true,'saving does not apply');assert(w.status:GetText():find('saved profile',1,true))
  click(w.actions.apply);equal(C.db.sniper,false);assert(w.status:GetText():find('imported',1,true))
  s:assertHealthy()
end)

test('profile guide examples never save, apply or send and clean up on return', function()
  local s=new('cata',{});local p,P,C=open(s)
  local before=P.ExportString(P.Snapshot());local saved=C.db.profiles.Default
  local O,coach=s.ns.Onboarding,s.ns.Onboarding.Coach
  O.Start('profile')
  local function go(id)for i,step in ipairs(coach.steps)do if step.id==id then coach.Go(i);coach.Update();return end end;error(id)end
  go('changes');assert(p.example and #p.reviewRows==3)
  assert(row(p.reviewRows,'positions.point'),'the safe guide example demonstrates a moved panel')
  assert(not p.profileButtons.Save:IsEnabled() and not p.profileButtons.Load:IsEnabled())
  equal(P.ExportString(P.Snapshot()),before,'example does not apply');equal(C.db.profiles.Default,saved,'example does not save')
  equal(#s.chat,0,'example does not send')
  coach.Replay();go('switching');assert(not p.example and p.assignments:IsVisible())
  go('changes');O.Return();assert(not p.example)
  equal(P.ExportString(P.Snapshot()),before,'return restores live settings')
  s:assertHealthy()
end)

test('profile commands and visible controls share save, update, delete and import behavior', function()
  local s=new('cata',{});local p,P,C=open(s)
  s:command('profile save Command profile')
  equal(C.db.activeProfile,'Command profile');equal(#p.reviewRows,0)
  C.SetFeature('sniper',false);s:command('profile save Command profile')
  equal(row(p.reviewRows,'features.sniper').before,'On');equal(row(p.reviewRows,'features.sniper').text,'Off')
  p.SelectProfile('Default');assert(not p.profileButtons.Update:IsShown())
  s:command('profile save Default');equal(C.db.profiles.Default.setup.features.sniper,true)
  s:command('profile delete Default');assert(C.db.profiles.Default,'command protects Default too')
  s:command('profile load Command profile');equal(C.db.activeProfile,'Command profile')
  P.Assign('Command profile','arena');s:command('profile delete Command profile')
  equal(C.db.activeProfile,nil);local who,key=P.Context('arena');equal(C.db.profileAssignments[who][key],nil)
  local snap=P.Snapshot();snap.points.killPer=12
  s:command('import '..P.ExportString(snap,'From chat'));equal(C.P('killPer'),12)
  s:command('export Default');assert(P.share:IsVisible() and P.share.mode=='export')
  s:command('import');assert(P.share.mode=='import')
  s:assertHealthy()
end)

test('turning switching off or clearing an activity cancels only automatic combat requests',function()
  local s=new('cata',{});create(s,'Other');local p,P,C=open(s)
  p.SelectProfile('Default');click(p.profileButtons.Load);s:setCombat(true)
  p.assignments.activities.world:SetValue('Other');p.assignments.enabled:SetChecked(true)
  assert(P.pending and P.pending.automaticAssignment)
  p.assignments.enabled:SetChecked(false);equal(P.pending,nil,'off cancels automatic request')
  p.assignments.enabled:SetChecked(true);assert(P.pending)
  p.assignments.activities.world:SetValue('none');equal(P.pending,nil,'unassigning cancels automatic request')
  P.LoadProfile('Other');p.assignments.enabled:SetChecked(false)
  equal(P.pending.profileName,'Other','manual Use profile remains queued')
  s:setCombat(false);equal(C.db.activeProfile,'Other');s:assertHealthy()
end)
