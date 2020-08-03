#!/bin/bash
# -*- mode: shell-script ; -*-
#
# fanout.sh: 
#       ---- Fan-out stdout/stderr output to multiple files.
#    Nanigashi Uji (53845049+nanigashi-uji@users.noreply.github.com)
#
function fanout () {
    # Prepare Help Messages
    local funcstatus=0
    local echo_usage_bk=$(declare -f echo_usage)
    local keepmergedout_bk=$(declare -f keepmergedout)
    local cleanup_bk=$(declare -f cleanup)
    local tmpfiles=()
    local tmpdirs=()

    local append=0
    local keep=0
    local merge=0
    local fstdo=()
    local fstde=()

    function  echo_usage () {
        if [ "$0" == "${BASH_SOURCE:-$0}" ]; then
            local this=$0
        else
            local this="${FUNCNAME[1]}"
        fi
        echo "[Usage] % $(basename ${this}) [options] [-o file] [-e file] [cmd [cmd_options .... ]]" 1>&2
        echo "[Options]"                                                                             1>&2
        echo "           -k      : Keep stdout/stderr (default)"                                     1>&2
        echo "           -d      : No stdout/stderr output"                                          1>&2
        echo "           -a      : append to existing files"                                         1>&2
        echo "           -m      : merge stdout and stderr outputs."                                 1>&2
        echo "           -o path : file name to dump stdout"                                         1>&2
        echo "           -e path : file name to dump stderr"                                         1>&2
        echo "           -h      : Show Help (this message)"                                         1>&2
        return
    }

    local hndlrhup_bk=$(trap -p SIGHUP)
    local hndlrint_bk=$(trap -p SIGINT) 
    local hndlrquit_bk=$(trap -p SIGQUIT)
    local hndlrterm_bk=$(trap -p SIGTERM)

    trap -- 'cleanup ; kill -1  $$' SIGHUP
    trap -- 'cleanup ; kill -2  $$' SIGINT
    trap -- 'cleanup ; kill -3  $$' SIGQUIT
    trap -- 'cleanup ; kill -15 $$' SIGTERM


    function keepmergedout () {
        local sofifo=$1
        shift
        local sefifo=$1
        shift
        (( "$@" | tee "${sofifo}" ) 3>&2 2>&1 1>&3  | tee "${sefifo}" ) 
        return
    }
    
    function cleanup () {
        
        # removr temporary files and directories
        if [ ${#tmpfiles} -gt 0 ]; then
            rm -f "${tmpfiles[@]}"
        fi
        if [ ${#tmpdirs} -gt 0 ]; then
            rm -rf "${tmpdirs[@]}"
        fi

        # Restore  signal handler
        if [ -n "${hndlrhup_bk}"  ] ; then eval "${hndlrhup_bk}"  ;  else trap --  1 ; fi
        if [ -n "${hndlrint_bk}"  ] ; then eval "${hndlrint_bk}"  ;  else trap --  2 ; fi
        if [ -n "${hndlrquit_bk}" ] ; then eval "${hndlrquit_bk}" ;  else trap --  3 ; fi
        if [ -n "${hndlrterm_bk}" ] ; then eval "${hndlrterm_bk}" ;  else trap -- 15 ; fi

        # Restore alias and functions

        unset echo_usage
        test -n "${echo_usage_bk}" && eval ${echo_usage_bk%\}}" ; }"

        unset keepmergedout
        test -n "${keepmergedout_bk}" && eval ${keepmergedout_bk%\}}" ; }"

        unset cleanup
        test -n "${cleanup_bk}" && eval ${cleanup_bk%\}}" ; }"
    }

    # Analyze command line options
    local OPT=""
    local OPTARG=""
    local OPTIND=""
    local dest="" 
    local verbose=0
    local vverbose=0
    while getopts "amkdho:e:vV" OPT
    do
        case ${OPT} in
            k) local keep=1
               ;;
            d) local keep=0
               ;;
            a) local append=1
               ;;
            m) local merge=1
               ;;
            o) local fstdo=( "${fstdo[@]}" "${OPTARG}" )
               ;;
            e) local fstde=( "${fstde[@]}" "${OPTARG}" )
               ;;
            v) local verbose=1
               ;;
            V) local vverbose=1
               ;;
            h) echo_usage
               cleanup
               return 0
               ;;
            \?) echo_usage
                cleanup
                return 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    local scriptpath=${BASH_SOURCE:-$0}
    local scriptdir=$(dirname ${scriptpath})
    if [ "$0" == "${BASH_SOURCE:-$0}" ]; then
        local this=$(basename ${scriptpath})
    else
        local this="${FUNCNAME[0]}"
    fi

    #local tmpdir0=$(mktemp -d "${this}.tmp.XXXXXX" )
    #local tmpdirs=( "${tmpdirs[@]}" "${tmpdir0}" )
    #local tmpfile0=$(mktemp   "${this}.tmp.XXXXXX" )
    #local tmpfiles=( "${tmpfiles[@]}" "${tmpfile0}" )

    if [ ${#fstdo[@]} -eq 0 -a ${#fstde[@]} -eq 0 ]; then
        "$@"
        return
    fi

    if [ $# -gt 0 ]; then
        local cmds=( "$@" )
    else
        local cmds=( "${CAT:-cat}" )
    fi
    
    local pipes=()

    local nso=$((${#fstdo[@]}-1))
    local nse=$((${#fstde[@]}-1))
    local nlast=$((${#fstdo[@]}+${#fstde[@]}-1))

    if [ ${merge:-0} -ne 0 ]; then
        local pipes=( "${pipes[@]}" "2>&1")
        declare -i n=0
        local i=
        for i in "${fstdo[@]}" "${fstde[@]}"; do
            if [ ${n} -lt ${nlast} ]; then
                if [ ${append:-0} -ne 0 ]; then
                    local pipes=( "${pipes[@]}" "|" "tee" "-a" "${i}" )
                else
                    local pipes=( "${pipes[@]}" "|" "tee" "${i}" )
                fi
            else
                if [ ${append:-0} -ne 0 ]; then
                    local pipes=( "${pipes[@]}" ">>" "${i}" )
                else
                    local pipes=( "${pipes[@]}" ">"  "${i}" )
                fi
            fi
            declare -i n=$((n+1))
        done

        if [ ${keep:-0} -ne 0 ]; then
            local sofifo=$(mktemp "${TMPDIR:-/tmp}/${this}.tmp.XXXXXX" )
            local sefifo=$(mktemp "${TMPDIR:-/tmp}/${this}.tmp.XXXXXX" )
            local tmpfiles=( "${tmpfiles[@]}" "${sofifo}" "${sefifo}" )

            ${RM:-rm} -f "${sofifo}" ; mkfifo "${sofifo}"
            ${RM:-rm} -f "${sefifo}" ; mkfifo "${sefifo}"

            # trap 'rm "${sofifo}" "${sefifo}"' RETURN
            cat "${sofifo}"       &
            cat "${sefifo}" 1>&2  &
            local pipes=( "(" keepmergedout "${sofifo}" "${sefifo}"  "${cmds[@]}" ")"  "${pipes[@]}" )
        else
            local pipes=( "${cmds[@]}" "${pipes[@]}" )
        fi
    else
        if [ ${append:-0} -ne 0 ]; then
            local add1=(">>")
            local add2=("|" "tee" "-a")
        else
            local add1=(">")
            local add2=("|" "tee")
        fi
        local i=0
        for ((i=0;i<${#fstdo[@]};++i)); do
            if [ ${keep:-0} -ne 0 -o \( ${i} -ne ${nlast} -a ${i} -ne ${nso} \) ]; then
                local pipes=( "${pipes[@]}" "${add2[@]}" "${fstdo[${i}]}" )
            else
                local pipes=( "${pipes[@]}" "${add1[@]}" "${fstdo[${i}]}" )
            fi
        done

        if [ ${#fstde[@]} -gt 0 ];then
            local pipes=( "(" "${cmds[@]}" "${pipes[@]}" ")" "3>&2" "2>&1" "1>&3" )
            for ((i=0;i<${#fstde[@]};++i)); do
                local j=$((i+${#fstdo[@]}))
                if [  ${keep:-0} -ne 0 -o \( ${j} -ne ${nlast} -a ${i} -ne ${nso} \) ]; then
                    local pipes=( "${pipes[@]}" "${add2[@]}" "${fstde[${i}]}" )
                else
                    local pipes=( "${pipes[@]}" "${add1[@]}" "${fstde[${i}]}" )
                fi
            done
            if [ ${keep:-0} -ne 0 ]; then
                local pipes=( "(" "${pipes[@]}" ")" "3>&2" "2>&1" "1>&3" )
            else
                local pipes=( "${pipes[@]}" )
            fi
        fi
    fi

    if [ ${vverbose:-0} -ne 0 ]; then
        echo "[${this}] ::: ${pipes[@]}"
        echo "[${this}] ::: ${pipes[@]}" 1>&2
    elif [ ${verbose:-0} -ne 0 ]; then
        echo "[${this}] ::: ${pipes[@]}"
    fi
    eval "${pipes[@]}"
    
    # clean up 
    cleanup
    return ${funcstatus}
}

if [ "$0" == ${BASH_SOURCE:-$0} ]; then
    fanout "$@"
fi
