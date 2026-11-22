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
  test(client .. ' profile creation previews presets without changing live settings and keeps full saved contents', function()
    local s = make(); local p, P, C = open(s)
    local before = P.ExportString(P.Snapshot())
    click(p.profileButtons.New); p.source:SetValue('preset:healer')
    equal(row(p.reviewRows,'features.sniper').text, 'Off')
    assert(row(p.reviewRows,'style.fontScale') and row(p.reviewRows,'positions.point') and row(p.reviewRows,'points.killPer'))
    equal(P.ExportString(P.Snapshot()), before, 'choosing a preset does not apply it')
    click(p.profileButtons.Copy); equal(P.ExportString(P.Snapshot()), before, 'cancel keeps settings')
    create(s, 'Healer BG', 'preset:healer')
    equal(C.db.activeProfile, 'Healer BG'); equal(C.db.sniper, false)
    assert(not P.ActiveState().modified,'a newly created preset matches the active setup')
    assert(#p.reviewRows > 100 and p.profileScroll.text:GetText():find('Sniper marker: Off',1,true))
    equal(C.db.profiles.Default.setup.features.sniper, true, 'Default keeps the starting setup')
    s:assertHealthy()
  end)
  test(client .. ' updates list all changes and keep their receipt until another edit', function()
    local s = make(); create(s, 'My setup')
    local p, P, C = open(s)
    C.SetFeature('sniper', false); C.SetPanelScale('main', 1.1); s.ns.Alerts.SetMode('objectives'); s:advance(0.6)
    assert(row(p.reviewRows,'features.sniper') and row(p.reviewRows,'style.scales.main') and row(p.reviewRows,'alerts.mode'))
    equal(row(p.reviewRows,'features.sniper').before,'On'); equal(row(p.reviewRows,'features.sniper').text,'Off')
    local count=#p.reviewRows; click(p.profileButtons.Save)
    equal(#p.reviewRows,count); assert(p.reviewTitle:GetText():find('Saved',1,true))
    s:advance(1.1); equal(#p.reviewRows,count,'idle refresh keeps receipt')
    equal(C.db.profiles['My setup'].setup.features.sniper,false)
    C.SetFeature('sniper',true); s:advance(0.6)
    equal(#p.reviewRows,1); equal(row(p.reviewRows,'features.sniper').before,'Off')
    equal(p.profileButtons.Update:GetText(),'Use saved copy')
    click(p.profileButtons.Update);equal(C.db.sniper,false,'restore active copy discards unsaved edits')
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
    assert(a:IsVisible() and a.activities.arena:IsVisible())
    a.activities.arena:SetValue('Arena'); a.enabled:SetChecked(true)
    local who,key=P.Context('arena'); equal(C.db.profileAssignments[who][key],'Arena')
    a.enabled:SetChecked(false); equal(C.db.profileAssignments[who][key],'Arena')
    p.SelectProfile('Default'); click(p.profileButtons.Load)
    s:setCombat(true); P.LoadProfile('Arena'); P.DeleteProfile('Arena')
    equal(P.pending,nil); equal(C.db.profileAssignments[who][key],nil)
    s:setCombat(false); equal(C.db.activeProfile,'Default'); s:assertHealthy()
  end)
  test(client .. ' profile controls fit both font scales while only reviews and saved lists scroll', function()
    local s=make({},true); create(s,'Healer with a longer profile name')
    local p,P,C=open(s)
    for _, scale in ipairs({1,1.5}) do
      for _, theme in ipairs({'highground','parchment'}) do
        s.ns.Theme.Use(theme); C.SetFontScale(scale); p.NewProfile()
        local function below(a,b) local x,y=s.bounds(a),s.bounds(b); assert(x[2]+x[4]<=y[2]+1,'controls do not overlap') end
        below(p.assignments,p.detail); below(p.profileName,p.source); below(p.profileScroll,p.actions)
        below(p.actions,p.profileStatus); below(p.profileStatus,p.footer)
        assert(p.profileScroll:GetHeight()>36,'review has a usable viewport')
        assert(p.profileStatus:GetHeight()>=p.profileStatus:GetStringHeight(),'status text fits')
        local top=s.bounds(p.assignments)[2];p.profileScroll:Scroll(p.profileScroll.range)
        equal(s.bounds(p.assignments)[2],top,'automatic switching never scrolls away')
        assert(p.profileButtons.Save:IsVisible() and p.profileButtons.Import:IsVisible())
        for _,key in ipairs({'Save','Copy','Import','Export','Chat','Delete'})do
          local b=p.profileButtons[key];assert(b.label:GetStringWidth()<=b:GetWidth()-12,key..' label fits')
        end
        p.SelectProfile('Default')
      end
    end
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
end

test('Default migration preserves both conflicting profiles and every saved reference', function()
  local s=new('cata',{});local P,C=s.ns.Options.Profiles,s.ns.Core
  P.SaveProfile('Default');C.SetFeature('sniper',false);P.SaveProfile('Before role preset')
  local starting=C.db.profiles.Default;local previous=C.db.profiles['Before role preset']
  C.db.activeProfile='Before role preset';C.db.profileDefaultVersion=nil
  C.db.profileAssignments={Alice={['one:bg']='Before role preset'},Bob={['two:arena']='Before role preset'}}
  P.MigrateDefault()
  equal(C.db.profiles.Default,starting);equal(C.db.profiles['Previous setup'],previous)
  equal(C.db.activeProfile,'Previous setup');equal(C.db.profileAssignments.Alice['one:bg'],'Previous setup')
  equal(C.db.profileAssignments.Bob['two:arena'],'Previous setup');equal(C.db.profiles['Before role preset'],nil)
  P.MigrateDefault();equal(C.db.profiles['Previous setup (2)'],nil,'idempotent migration')
end)
test('Default migration without a collision and repeated presets keep the original snapshot', function()
  local s=new('cata',{});local P,C=s.ns.Options.Profiles,s.ns.Core
  P.SaveProfile('Before role preset');local before=C.db.profiles['Before role preset'];C.db.profileDefaultVersion=nil
  P.MigrateDefault();equal(C.db.profiles.Default,before)
  assert(s.ns.Setup.Apply('healer'));assert(s.ns.Setup.Apply('damage'))
  equal(C.db.profiles.Default,before,'later presets never replace Default')
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
  assert(row(rows,'positions.point').text:find('x 0, y -27',1,true));equal(row(rows,'cooldowns.2139').text,'Off')
  local legacy=P.Snapshot();legacy.setup=nil
  for _,r in ipairs(P.Review(legacy,next))do assert(not r.id:match('^style%.') and not r.id:match('^features%.'),'legacy scope')end
  next.setup.style.loop=next.setup.style;assert(not P.Review(next,old),'malformed snapshots rejected')
end)
test('clipboard imports review updates and applications before action and keep saved receipts', function()
  local s=new('cata',{});create(s,'Saved');local p,P,C=open(s)
  local snap=P.Snapshot();snap.setup.features.sniper=false
  P.ShowImport();local w=P.share;w.box:SetText(P.ExportString(snap,'Saved'))
  assert(w.review.text:GetText():find('On → Off',1,true),'before and after are shown before saving')
  equal(C.db.profiles.Saved.setup.features.sniper,true)
  click(w.actions.save);equal(C.db.profiles.Saved.setup.features.sniper,false)
  equal(C.db.sniper,true,'saving does not apply');assert(w.review.text:GetText():find('Saved',1,true))
  click(w.actions.apply);equal(C.db.sniper,false);assert(w.review.text:GetText():find('Applied',1,true))
  s:assertHealthy()
end)

test('profile guide examples never save, apply or send and clean up on return', function()
  local s=new('cata',{});local p,P,C=open(s)
  local before=P.ExportString(P.Snapshot());local saved=C.db.profiles.Default
  local O,coach=s.ns.Onboarding,s.ns.Onboarding.Coach
  O.Start('profile')
  local function go(id)for i,step in ipairs(coach.steps)do if step.id==id then coach.Go(i);coach.Update();return end end;error(id)end
  go('changes');assert(p.example and #p.reviewRows==3)
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
  equal(C.db.activeProfile,'Command profile');assert(#p.reviewRows>100)
  C.SetFeature('sniper',false);s:command('profile save Command profile')
  equal(row(p.reviewRows,'features.sniper').before,'On');equal(row(p.reviewRows,'features.sniper').text,'Off')
  p.SelectProfile('Default');click(p.profileButtons.Update)
  assert(row(p.reviewRows,'features.sniper'));click(p.profileButtons.Save)
  equal(C.db.profiles.Default.setup.features.sniper,false,'UI can update a nonactive saved name with current settings')
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
