# Sourced by Insight (--tclcommand) once started. Makes the "Run" button connect to the GDB stub given in the
# GDB_TARGET environment variable (HOST:PORT), as if "Remote/TCP" had been chosen in the target selection dialog.
proc docker_connect_target {} {
  global env gdb_target_name gdb_target_cmd
  if {![info exists env(GDB_TARGET)] || ![regexp {^(.+):([0-9]+)$} $env(GDB_TARGET) -> host port]} {
    return
  }
  debug "Run button connects to $host:$port"
  set gdb_target_name remotetcp
  set gdb_target_cmd ""
  pref setd gdb/load/remotetcp-hostname $host
  pref setd gdb/load/remotetcp-portname $port

  # Run options of the target: attach, download, run, continue
  set run_list [TargetSelection::getname remotetcp runlist]
  pref set gdb/src/run_attach [lindex $run_list 0]
  pref set gdb/src/run_load   [lindex $run_list 1]
  pref set gdb/src/run_run    [lindex $run_list 2]
  pref set gdb/src/run_cont   [lindex $run_list 3]

  # Programs without exit() (e.g. libnds ones) would ask whether to make the breakpoint at exit pending
  if {[catch {gdb_cmd "info address exit"}]} {
    pref set gdb/load/exit 0
  }
}

# Loading an executable (also at startup, after this script) restores its saved session, which resets the target
# and run options, so apply them again after it
auto_load ::Session::notice_file_change
rename ::Session::notice_file_change ::Session::notice_file_change_orig
proc ::Session::notice_file_change {} {
  notice_file_change_orig
  ::docker_connect_target
}
docker_connect_target
