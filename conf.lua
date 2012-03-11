-- vim:et

function love.conf(t)
  t.title="NetWars"
  t.author="Borg <borg@uu3.net>"
  t.identity="netwars"
  t.console=false
  t.screen.width=800
  t.screen.height=600
  t.modules.joystick=false
  t.modules.physics=false
  t.modules.audio=false
  t.modules.sound=false
end
