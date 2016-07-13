#!/bin/sh
. ./test-lib.sh
t_plan 5 "before murder is called only once"

t_begin "setup and start" && {
	unicorn_setup
	cat >> $unicorn_config <<EOF
timeout 5
after_fork { |s,w| File.open('$fifo','w') { |f| f.write '.' } }
class Unicorn::HttpServer
  def kill_worker(signal, wpid)
    @iteration ||= 0
    \$stderr.puts "kill_worker #{signal} #{wpid} #{@iteration}"
    if @iteration > 0 then
      Process.kill(signal, wpid)
    end
    @iteration = @iteration + 1
  rescue Errno::ESRCH
    @before_murder_called.delete(wpid)
    worker = @workers.delete(wpid) and worker.close rescue nil
  end
end
before_murder do |s, w, p| 
  \$stderr.puts "before murder called:"
end
EOF
	unicorn -c $unicorn_config before_murder.ru &
	test '.' = $(cat $fifo)
	unicorn_wait_start
}

t_begin "start worker=0" && {
	pid=$(curl http://$listen/) || true
}

t_begin "ensure before murder log is present once and killing is present twice" && {
	dbgcat r_err
	grep 'before murder called:' $r_err 
  test 1 -eq $(grep "before murder called:" $r_err | count_lines)
  test 2 -eq $(grep timeout $r_err | grep killing | count_lines)
  test 2 -eq $(grep "kill_worker KILL" $r_err | count_lines)
	dbgcat r_err
	> $r_err
}

t_begin "killing succeeds" && {
  kill $unicorn_pid
  wait
  kill -0 $unicorn_pid && false
}

t_begin "check stderr" && {
	check_stderr
}

t_done
