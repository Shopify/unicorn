#!/bin/sh
. ./test-lib.sh
t_plan 5 "before murder is called"

t_begin "setup and start" && {
	unicorn_setup
	cat >> $unicorn_config <<EOF
timeout 5
after_fork { |s,w| File.open('$fifo','w') { |f| f.write '.' } }
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

t_begin "ensure before murder log is present" && {
	dbgcat r_err
	grep 'before murder called:' $r_err 
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
