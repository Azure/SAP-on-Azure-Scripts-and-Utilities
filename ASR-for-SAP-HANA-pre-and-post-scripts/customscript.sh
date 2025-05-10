#### customscript.sh

    #!/bin/bash    
    if [ $# -ne 1 ]; then
        echo "Usage: $0 [--pre | --post]"
        exit 1
    elif [ "$1" == "--pre" ]; then
        /usr/local/ASR/Vx/scripts/asr4hana_pre.sh
        exit 0
    elif [ "$1" == "--post" ]; then
        /usr/local/ASR/Vx/scripts/asr4hana_post.sh
        exit 0
    fi