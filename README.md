# fanout_sh
Fan-out stdout/stderr output to multiple files for CLI.

# Usage

```
% fanout.sh [options] [-o file] [-e file] [cmd [cmd_options .... ]]
[Options]
           -k      : Keep stdout/stderr (default)
           -d      : No stdout/stderr output
           -a      : append to existing files
           -m      : merge stdout and stderr outputs.
           -o path : file name to dump stdout
           -e path : file name to dump stderr
           -h      : Show Help (this message)
```
