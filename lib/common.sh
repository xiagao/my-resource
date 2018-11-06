# Log level: 4 (DEBUG) -> 1 (ERROR)
LOG_LVL=${LOG_LVL:-3}
_log()
{
    local LVL=$1; shift
    if [ "$LVL" -le "$LOG_LVL" ]; then
        echo -e $*
    fi
}
_log_debug()    { _log 4 "\033[34mDEBUG\033[0m\t" $*; }
_log_info()     { _log 3 "\033[32mINFO\033[0m\t" $*; }
_log_warn()     { _log 2 "\033[33mWARN\033[0m\t" $* >&2; }
_log_error()    { _log 1 "\033[31mERROR\033[0m\t" $* >&2; }

_exit_on_error() { if [ $? -ne 0 ]; then _log_error $*; exit 1; fi; }
