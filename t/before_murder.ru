use Rack::ContentLength
use Rack::ContentType, "text/plain"
app = lambda do |env|
  Process.kill(:STOP, Process.pid)
  [ 200, {}, [ "#$$\n" ] ]
end
run app
