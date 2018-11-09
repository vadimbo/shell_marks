#!/bin/sh

#------------------------------------------------------------------------------
exitStatus()
#------------------------------------------------------------------------------
{
    case $1 in 
    0) echo "Instalation successfull. Please relogin.";;
    1) echo "Error: This tool requires KSH to be installed. Please consider to install Korn Shell first." >&2 ;;
    2) echo "Error: Could not create dir <$2>" >&2 ;;
    3) echo "Error: Could not save script content under <$2>" >&2 ;;
    4) echo "Error: Could not create/give execute permission to <$2>" >&2 ;;
    5) echo "Error: Could not modify <$2> file" >&2 ;;
    6) echo "Error: Instalation was done alreay. Did you try to relogin? " >&2 ;;
    20) echo "Info: No changes were done.";;
    *) echo "Error: An unexpected error occured." >&2;;
    esac

    exit $1
}

#------------------------------------------------------------------------------
getIniFile()
#------------------------------------------------------------------------------
{
    case $1 in
    bash) echo ".bashrc" ;;
    sh  ) echo ".profile";;
    ksh ) echo ".profile";;
    csh ) echo ".cshrc"  ;;
    tcsh) echo ".tcshrc" ;;
    zsh ) echo ".zshrc"  ;;
    *)    echo ".profile";;
    esac
}

#------------------------------------------------------------------------------
changeIniFile ()
#------------------------------------------------------------------------------
{
    # in case we have ini file as .cshrc and there exists .tcshrc then swith to
    # .tcshrc and in case we have ini file as .tcshrc and there is no .tcshrc but 
    # there is .cshrc then swith to .cshrc
    INIF=$1
    [ $INIF = ".cshrc" -a -r $HOME/.tcshrc ] && INIF=".tcshrc"
    [ $INIF = ".tcshrc" -a ! -r $HOME/.tcshrc -a -r $HOME/.cshrc ] && INIF=".cshrc"

    [ -r $HOME/$INIF ] && INIF_EXIST=Y 
    if [ ${INIF_EXIST:-N} != Y ] ; then
       touch $HOME/$INIF 
       [ $? -ne 0 ] && echo "Error: Could not create $HOME/$INIF" >&2 && return 1
    fi

    [ -h $HOME/$INIF ] && INIF_LINK=Y
    # take backup of current file
    if [ ${INIF_LINK:-N} = Y ]; then
        mv $HOME/$INIF $HOME/${INIF}_
    elif [ ${INIF_EXIST:-N} = Y ]; then
        cp $HOME/$INIF $HOME/${INIF}_bck_`date "+%Y%m%d_%H%M%S"` 
    fi
    INIF_CONTENT=`cat $HOME/$INIF 2> /dev/null`

    case $INIF in 
    ".profile"|".bashrc"|".kshrc"|".zshenv")
        ( echo "$INIF_CONTENT" | awk '/install_shm\.sh.*begin/,/install_shm\.sh.*end/{next}{print}'
          [ ${INIF_LINK:-N} = Y ] && echo ". \${HOME}/${INIF}_"
          cat << EOF
# Added by install_shm.sh (shell marks tool): begin
j()
{
   cd "\`path \$1\`"
}
je()
{
   cd "\`exe \$1\`"
}

alias go='j'
alias jump='j'
# Added by install_shm.sh (shell marks tool): end
 
EOF
          # check if need to add instalation path to PATH env var
          echo $PATH | grep -q "$HOME/bin" || echo "PATH=$INSTALL_DIR:\$PATH"
        ) > $HOME/$INIF
        [ $? -ne 0 ] && return 1
        ;;

   ".cshrc"|".tcshrc")
        ( echo "$INIF_CONTENT" | awk '/install_shm\.sh.*begin/,/install_shm\.sh.*end/{next}{print}'
          [ ${INIF_LINK:-N} = Y ] && echo "source \${HOME}/${1}_"
          cat << EOF
# Added by install_shm.sh (shell marks tool): begin 
alias go 'cd "\`path \\!*\`"'
alias jump 'cd "\`path \\!*\`"'
alias j 'cd "\`path \\!*\`"'
alias je 'cd "\`exe \\!*\`"'
# Added by install_shm.sh (shell marks tool): end
 
EOF
          # check if need to add instalation path to PATH env var
          echo $PATH | grep -q "$HOME/bin" || echo "set PATH = $INSTALL_DIR:\$PATH"
        ) > $HOME/$INIF
        [ $? -ne 0 ] && return 1
        ;;
    esac
    return 0
}
#------------------------------------------------------------------------------
# Create a hard link if possible for a input name to "mark" command
#------------------------------------------------------------------------------
createLink()
{
    if [ -r $1 ] ; then
        echo "Warning: $1 already exists" >&2
    else
        ln mark $1 2> /dev/null || echo "Warning: Could not create hard link for mark as $1" >&2 
    fi
}
#------------------------------------------------------------------------------
# Check if KSH is installed
#------------------------------------------------------------------------------
#which ksh > /dev/null
#[ $? -ne 0 ] && exitStatus 1

#------------------------------------------------------------------------------
# Check for instalation dir
#------------------------------------------------------------------------------
CURR_PATH=`pwd`

INSTALL_DIR=$HOME/bin
if [ ! -d $INSTALL_DIR ]; then
    mkdir $INSTALL_DIR
    [ $? -ne 0 ] && exitStatus 2 "$INSTALL_DIR"
else
    cd $INSTALL_DIR
    if [ -r mark -a -x mark ] ; then
        echo "Info: Looks like instalation was run already. Are you sure you want to continue [Y/n]?"
        read ANSWER
        [ ${ANSWER:-n} != Y ] && exitStatus 20
    fi
fi

#------------------------------------------------------------------------------
# install the script itself
#------------------------------------------------------------------------------


cd "$INSTALL_DIR"
echo "Info: Changed current directory to $INSTALL_DIR"
cat $CURR_PATH/${0} | sed -n '/^###.*INSTALL.*FROM.*HERE.*###$/,$p' | sed 1d > mark
[ ! -r mark ] && exitStatus 3 "$INSTALL_DIR/mark"

#------------------------------------------------------------------------------
# Give execute permissions
#------------------------------------------------------------------------------
chmod +x mark
[ $? -ne 0 ] && exitStatus 4 "$INSTALL_DIR/mark"

#------------------------------------------------------------------------------
# Create rest of the tools (links)
#------------------------------------------------------------------------------
createLink m
createLink p
createLink e
createLink d
createLink c
createLink path 
createLink exe
createLink cmd
createLink del
#------------------------------------------------------------------------------
# Check if mandatory tools were created
#------------------------------------------------------------------------------
[ ! -x mark ] && exitStatus 4 "$INSTALL_DIR/mark"
[ ! -x path ] && exitStatus 4 "$INSTALL_DIR/path"
[ ! -x exe ] && exitStatus 4 "$INSTALL_DIR/exe"
[ ! -x del ] && exitStatus 4 "$INSTALL_DIR/del"

#------------------------------------------------------------------------------
# Create some basic defualt commands
#------------------------------------------------------------------------------
./mark -l ff 'find . -type f -name "$1" # searches for files'
./mark -l fd 'find . -type d -name "$1" # searches for directories'
./mark -l finf 'exe ff "$1" | xargs grep -il "$2" # find in files '
./mark -l pop 'cat `echo ${*:-0} | sed "s%\([^ ]\{1,\}\)%/tmp/stack\1%g"` # reads out from stacks $* to stdout'
./mark -l put 'cat > /tmp/stack${1:-0} # puts the content of stdin to stack $1, default 0'
./mark -l push 'cat >> /tmp/stack${1:-0} # adds the content of stdin to stack $1, default 0'
./mark svi 'vi /tmp/stack${1:-0} # open stack $1 for editing'
./mark sls 'printf "%s " `ls -1rt /tmp/stack* | sed "s%/tmp/stack%%"`; echo "" # lists current used stacks'

#------------------------------------------------------------------------------
# determine shell init file and change it accordingly
#------------------------------------------------------------------------------


WHOAMI=`whoami`
SHELL=`sed -n "/^$WHOAMI:/p" /etc/passwd | awk -F':' '{print $7}'`
INIFILE=`getIniFile ${SHELL##*/}`

# Check if ini file is not changed already then do changes in it
PREV_CHANGED_IND=`awk '/install_shm\.sh.*shell/{print}/alias.*path/{print}/cd.*path/{print}' $HOME/$INIFILE 2> /dev/null`
if [ -z ${PREV_CHANGED_IND:-""} ] ; then
    changeIniFile $INIFILE || exitStatus 5 "$INIFILE"
else
    exitStatus 6
fi

exitStatus 0

################### INSTALL FROM HERE #########################################
#!/bin/ksh

EXENAME=${0:##*/}
SCR_PATH=${0:%/*}
[[ $SCR_PATH = $EXENAME ]] && SCR_PATH="."

CONF_FILE=${BOOK_MARK_CFG_FILE:-"${HOME}/.mcfg_default"}


#--------------------------------------------------------------
function showUsage 
#--------------------------------------------------------------
{
    case $EXENAME in
    ("mark"|"m")
        cat << EOF | more
    Usage: $EXENAME [options] [mark_name] [value] 
           add/change shell "mark" (a path or shell command(s) or another existing mark) and label 
           this with chosen "mark_name".

      mark_name - will specify under which name "mark_name" value will be saved. In this case "mark_value" 
           can be anything representing a directory you need to refer or a set of shell commands or a name 
           to an existing already mark. When this parameter is not provided it takes by default value 0.

      value - string which should be saved under specified mark_name. This string can be anything you 
           need to refer after. If parameter not provided it will take current directory by default 
           (i.e.<`pwd`>).
           If value is matching to some existing already "mark_name" then this value will be treated as a reference.
           i.e > mark my_mark "`pwd`"
           > mark another_my_mark my_mark  - In this case 'another_my_mark' will resolve to value of 'my_mark' 
           > path another_my_mark
           `pwd`

      Options: 

        -h Display this help

        -V Show tool version.

        -l When specified it will create a link with specified "mark name" under the same place where $EXENAME is 
           situated which will enable to execute shell mark as a unix command. i.e. instead of calling 
           > exe "mark" [params_if_any] you will be able to type directly
           > mark [params_if_any]. For more details see exe -h

      For additional info:
           type path -h for more info about how to retrieve/search marks
           type exe -h  for more info about how to execute "executable" marks
           type del -h  for more info about how to delete marks
        
EOF
        ;;
    ("path"|"p"|"cmd"|"c")
        cat << EOF | more

    Usage: $EXENAME [Options] [name] 
           get the value of a shell "mark" by specifying it's name. It can be also used to display or search 
           for some marks from current available list.

       name - When no options are specified this will represent the name of some existing mark. If name is
           not matching to any a "." will be returned. If parameter not specified 0 is considered as a mark
           name by default.
           i.e. > mark my_mark "`pwd`"
           > path my_mark

           Note: "all" is a reserved keyword and it means all existing marks will get displayed.

     Options:

        -h Display this help.

        -V Show tool version.

        -n Treat "name" as a search pattern to be used for searching in existing list of marks' names
           i.e. > mark my_mark "`pwd`"
           > mark my_cmd 'echo "Hello World"'
           > path -n ^my  - will display all marks which starts with "my" in the names
           my_mark->`pwd`
           my_cmd->echo "Hello World"

        -p Treat "name" as a search pattern to be used for searching in existing list of mark's values
           i.e. > mark my_mark "`pwd`"
           > mark my_cmd 'echo "Hello World"'
           > path -p echo  - will display all marks which contains "echo" in their values
           my_cmd->echo "Hello World"

        -r Indicate to show mark values as \${other_mark} if the values represents references to other marks
           i.e. > mark my_mark "`pwd`"
           > mark my_other_mark my_mark
           > path -nr my_other_mark
           my_other_mark->\${my_mark}
           > path -n my_other_mark
           my_other_mark->my_mark

           This option is valid only if -n or -p is specified.

        -v Indicate to show also actual value to which a reference mark is being resolved.
           i.e. > mark my_mark "`pwd`"
           > mark my_other_mark my_mark
           > path -nrv my_other_mark
           my_other_mark->\${my_mark} => `pwd`

           This option works only if -r was specified.

           When some mark was created with -l option then an * will get shown in front of mark's name to 
           indicate it can be executed directly: > mark [parameters] instead of >exe mark [parameters]
           Valid only when -n or -p was specified.
           
      Note: You could use $EXENAME to change current path to most used directories you are 
           working with. i.e. mark my_path "`pwd`"  
           Then to change current directory to your mark you could type cd "\`path my_path\`"

           To make things even easier you could add to your .profile file or whatever init file
           you have according to your shell something like:
           go
           {
               cd "\`path \$1\`"
           }

           Then (after loggin in again) to change current dir to your directory you just type
           > go my_path

      For additional info:
               type mark -h for more info about how to create marks
               type exe -h  for more info about how to execute "executable" marks
               type del -h  for more info about how to delete marks.

EOF
        ;;
    ("exe"|"execute"|"ex"|"e")
        cat << EOF | more
    Usage:

    $EXENAME [options] [name] - used to "execute" a shell mark identified by its name as it would be 
           executed from your command line.
           For more details how exactly "marks" are retrieved check path -h or type path "mark_name".
           Returned result is exactly what will be executed.
      
           It is possible to pass input parameters to executed "mark" as that "mark" is expecting to get.
           i.e. We are making the following mark
           > mark f 'find . -type f -name "\$1"'
           > $EXENAME f '*txt'  - this will execute find command and '*txt' will be passed as parameter.
      
           if our "mark" f would be done using option -l i.e. > mark -l f 'find . -type f -name "\$1"'
           then above command would be possible to do by calling directly :
           > f '*txt'
      
           Note: Redirections are possible up to 9 levels. i.e. based on above example we could 
           make another "mark" of finding something from searched files. Thus this is also possible:
           > mark -l finf '$EXENAME f "\$1" | xargs grep -li "\$2"'
           and in case if f was created with -l option
           > mark -l finf 'f "\$1" | xargs grep -li "\$2"'
           then to use it:
           > finf '*txt' 'marks'

      Options:

        -h Display this help.

        -V Show tool version.

      For additional info:
           type mark -h for more info about how to create marks
           type path -h for more info about how to retrieve/search marks.
           type del -h  for more info about how to delete marks.

EOF
        ;;
    ("del"|"delete"|"d")
        cat << EOF | more
    Usage:

    $EXENAME [Options] name - used to delete mark(s) identified by name or found by pattern (see options).

       name - Will specify specific mark for deletion
    
       Options:

        -h Display this help.

        -V Show tool version.

        -n Name as a search pattern to be used for searching in existing list of mark's names

        -p Name as a search pattern to be used for searching in existing list of mark's values
        
        -i Will not ask for deletion confirmation. Asked by default if this parameter is not specified.
             

      For additional info:
           type mark -h for more info about how to create marks
           type path -h for more info about how to retrieve/search marks.
           type exe -h  for more info about how to delete marks.

EOF
        ;;
    (*)
        cat << EOF
    command <$EXENAME> is being evaluated (executed) as:
    `path $EXENAME`

    For more details type path -h.
EOF
        ;;
    esac

    return 0
}

#--------------------------------------------------------------
function getOptions
#--------------------------------------------------------------
{
    PARAM_CNT=0
    while getopts $READ_OPT option;
    do
       case $option in
       i)
           OPT_I=Y
           ;;
       l)
           OPT_L=Y
           ;;
       r)
           OPT_R=Y
           ;;
       p)
           OPT_P=Y
           ;;
       n)
           OPT_N=Y
           ;;
       v)
           OPT_V=Y
           ;;
       V)
           OPT_VC=Y
           ;;
       h)
           OPT_H=Y
           ;;
       :)
           echo "option -$OPTARG exppects an argument" >&2 && exit 1
           ;;
        *)
           echo "Invalid option -$OPTARG. Type $EXENAME -h for more info." >&2 && exit 1
           ;;
        esac
    done
    return $(($OPTIND-1))
}


#--------------------------------------------------------------
function execute
#--------------------------------------------------------------
{
    eval "$EXE"
}
    
#--------------------------------------------------------------
function showVersion
#--------------------------------------------------------------
{
    eval `sed -n '/^[[:space:]]*#k=/{
    s_.*#__
    s_k_c&_g
    s_ck_er_
    s_.*_v&_
    p
    }' $SCR_PATH/$EXENAME`    
    ckc=`grep -v '^[[:space:]]*#' $SCR_PATH/$EXENAME | cksum | awk '{print $1}'`
    [[ $ck -eq $ckc ]] && echo -e "Version $ver "
    [[ $ck -ne $ckc ]] && echo -e "This is a modified version on top of $ver"
    echo "Author: Vadim Bogulean (bogulean@yahoo.com)"
    return 0
}
#--------------------------------------------------------------
list_items()
#--------------------------------------------------------------
{
    while read LINE 
    do
        F1=`echo "$LINE" | awk -F'#%#' '{print $1}'`
        F2=`echo "$LINE" | awk -F'#%#' '{print $2}'`
        F2S="`echo "$F2" | sed 's%[^[:alnum:]{}()|]%\\\&%g'`"
        RESOLVE_FURTHER=`echo "${CONF_ITEMS}" | sed -n '/^'"$F2S"'#%#/{
        s/^.*#%#//
        p
        }'`
        [[ -z $1 || -z $RESOLVE_FURTHER ]] && RESOLVE_FURTHER="." 
        EXISTS_EXE="" && [[ -r $SCR_PATH/$F1 && -x $SCR_PATH/$F1 ]] && EXISTS_EXE='*'
        if [[ $RESOLVE_FURTHER = "." ]]; then
             echo "${EXISTS_EXE}$F1->$F2"
        else
            if [[ -z $2 ]]; then 
                echo "${EXISTS_EXE}$F1->\${$F2}"
            else
                echo "${EXISTS_EXE}$F1->\${$F2} => "`path "$F2S"`
            fi
        fi
    done
}
#--------------------------------------------------------------
case $EXENAME in

#--------------------------------------------------------------
# mark
#--------------------------------------------------------------
("mark"|"m")

    READ_OPT=":lhV"
    getOptions $*
    shift $?

    [[ $OPT_H = Y ]] && showUsage && exit 0
    [[ $OPT_VC = Y ]] && showVersion && exit 0

    INDEX=${1:-""}
    CREATE_LINK=$OPT_L
    [[ -n $INDEX ]] && shift && VALUE="${*:-}"
    [[ -z $VALUE ]] && VALUE=`pwd`
    [[ -z $INDEX ]] && INDEX=0

    # set VALUE_NUM if VALUE contains only numbers

    # if file where we store the marks doesn't exists, we create it
    if [[ ! -r ${CONF_FILE} ]]; then
        touch ${CONF_FILE}
    fi
    
    # read shell marks in VAL_ITEMS variable
    VAL_ITEMS=`cat ${CONF_FILE} | grep '#%#'`
    #--------------------------------------------------------------------------
    ( echo "$VAL_ITEMS" | \
      sed "/^${INDEX}#%#/d;/^\$/d" | sort -t'#' -k1,1 
      echo "${INDEX}#%#${VALUE}" ) > ${CONF_FILE}_
    [[ $CREATE_LINK = Y ]] && cd $SCR_PATH && ln $EXENAME $INDEX 2> /dev/null
    [[ $? -ne 0 && $CREATE_LINK = Y ]] && echo "Was not able to create link to <$EXENAME> under name <$INDEX>" >&2

    #--------------------------------------------------------------------------
    # Validate changes done before moving into our CONFIG_FILE
    # We should have at least same number of lines as before.
    if [[ -s ${CONF_FILE}_ ]]; then
        ORIG_FILE_LINES=`cat ${CONF_FILE} | wc -l`
        NEW_FILE_LINE=`cat ${CONF_FILE}_ | wc -l`
        if [[ $NEW_FILE_LINE -lt $ORIG_FILE_LINES ]]; then 
            echo "Failed to add your command/text to ${CONF_FILE} file." >&2
        else
            cat ${CONF_FILE}_ > ${CONF_FILE}
        fi
    else
        echo "Failed to add your command/text to ${CONF_FILE} file." >&2
    fi
    rm ${CONF_FILE}_ 2> /dev/null
    ;;

#--------------------------------------------------------------
# delete 
#--------------------------------------------------------------
("del"|"d"|"delete")

    READ_OPT=":nphiV"
    getOptions $*
    shift $?

    [[ $OPT_H = Y ]] && showUsage && exit 0
    [[ $OPT_VC = Y ]] && showVersion && exit 0

    [[ $OPT_P = Y && $OPT_N = Y ]] && exit "Only one option should be used at a time: -n/-p" >&2 && exit 1
    SEARCH_IN=""
    [[ $OPT_P = Y ]] && SEARCH_IN="-p"
    [[ $OPT_N = Y ]] && SEARCH_IN="-n"

    DELPAT=${1}
    [[ -z $DELPAT ]] && echo "You should specify a shell mark name or pattern for deletion" >&2 && exit 1
    DEL_LINES=`path $SEARCH_IN "$DELPAT"`
    [[ -z $SEARCH_IN && $DEL_LINES = "." ]] && DEL_LINES=""
    [[ -z $SEARCH_IN && -n $DEL_LINES ]] && DEL_LINES="$DELPAT->$DEL_LINES"
    [[ -z $DEL_LINES ]] && echo "Nothing to delete for $DELPAT" >&2 && exit 1 
    if [[ $OPT_I = Y ]]; then
        echo "The following lines were deleted."
        echo "$DEL_LINES"
        ANSWER=Y
    else
        echo "The following lines will be deleted. Are you sure [Y/n]?"
        echo "$DEL_LINES"
        read ANSWER
    fi
    [[ $ANSWER = Y && -z $SEARCH_IN ]] && \
    awk -F'#%#' "{ if (!(\$1 == "'"'$DELPAT'"'")) {print}}" ${CONF_FILE} > ${CONF_FILE}_
    [[ $ANSWER = Y && $SEARCH_IN = "-n" ]] && \
    awk -F'#%#' "{ if (!(\$1 ~ /$DELPAT/)) {print}}" ${CONF_FILE} > ${CONF_FILE}_
    [[ $ANSWER = Y && $SEARCH_IN = "-p" ]] && \
    awk -F'#%#' "{ if (!(\$2 ~ /$DELPAT/)) {print}}" ${CONF_FILE} > ${CONF_FILE}_
    for ITEM in `echo "$DEL_LINES" | awk -F'->' '{print $1}' | sed 's/\*//'`
    do
        case $ITEM in 
        ("mark"|"m"|"path"|"p"|"exe"|"ex"|"e"|"execute"|"d"|"del"|"delete")
            ;;
        (*)
            [[ -r $SCR_PATH/$ITEM ]] && rm $SCR_PATH/$ITEM 2> /dev/null
            ;;
        esac
    done
    #--------------------------------------------------------------------------
    if [[ -s ${CONF_FILE}_ ]]; then
        DEL_CNT=`echo "$DEL_LINES" | sed '/^-----/d' | wc -l`
        ORIG_FILE_LINES=`cat ${CONF_FILE} | wc -l`
        NEW_FILE_LINE=`cat ${CONF_FILE}_ | wc -l`
        if [[ $(($NEW_FILE_LINE+$DEL_CNT)) -lt $ORIG_FILE_LINES ]]; then 
            echo "Failed to delete your command(s)/references from ${CONF_FILE} file." >&2
        else
            cat ${CONF_FILE}_ > ${CONF_FILE}
        fi
        rm ${CONF_FILE}_ 2> /dev/null
    fi
    ;;
#--------------------------------------------------------------
# path
#--------------------------------------------------------------
("path"|"p"|"cmd"|"c")

    READ_OPT=":nprvVh"
    getOptions $*
    shift $?

    [[ $OPT_H = Y ]] && showUsage && exit 0
    [[ $OPT_VC = Y ]] && showVersion && exit 0

    [[ $RECURSION -gt 9 && $RECURSION_NOMSG != Y ]] && \
    echo "Your input creates recursion more than $RECURSION times." >&2 
    [[ $RECURSION -gt 9 ]] && echo "." && exit 1
    export RECURSION=$((${RECURSION:-0}+1)) 

    [[ $OPT_P = Y ]] && SHOWBYP=Y 
    [[ $OPT_N = Y ]] && SHOWBYN=Y 
    [[ $OPT_R = Y ]] && RESOLVE_REF=Y 
    [[ $OPT_V = Y ]] && RESOLVE_VALUES=Y 

    [[ $SHOWBYP = Y && $SHOWBYN = Y ]] && echo "Only one parameter can be specified at a time. (-n/-p)" >&2 && exit 1

    INDEX=${1:-"0"}
    CONF_ITEMS=`cat ${CONF_FILE} 2> /dev/null | grep '#%#'`
    
    #--------------------------------------------------------------------------
    # if we have our config file and we can work with
    if [[ -f ${CONF_FILE} ]]; then
       if [[ $INDEX = "all" ]]; then
           echo -------------------------
           echo "${CONF_ITEMS}" | list_items "$RESOLVE_REF" "$RESOLVE_VALUES"
           echo -------------------------
       elif [[ $SHOWBYN = Y ]]; then
           echo -------------------------
           echo "${CONF_ITEMS}" | awk -F'#%#' '{ if ($1 ~ /'"$INDEX"'/) print $0 }' | \
           list_items "$RESOLVE_REF" "$RESOLVE_VALUES" 
           echo -------------------------
       elif [[ $SHOWBYP = Y ]]; then
           echo -------------------------
           echo "${CONF_ITEMS}" | awk -F'#%#' '{ if ($2 ~ /'"$INDEX"'/) print $0 }' | \
           list_items "$RESOLVE_REF" "$RESOLVE_VALUES"
           echo -------------------------
       else
           set -f
           #k=\\061\\056\\060\\056\\062 k=2560311562
           INDEX=`echo "$INDEX" | sed 's%[^[:alnum:]{}()|]%\\\&%g'`
           RESULT=`echo "${CONF_ITEMS}" | sed -n '/^'"$INDEX"'#%#/{
           s/^.*#%#//
           p
           }'`
           [[ -z $RESULT ]] && RESULT="."
           if [[ "$RESULT" != "." ]]; then
               RESULT1=`path "$RESULT"`
               if [[ "$RESULT1" != "." ]]; then
                   echo "$RESULT1"
               else
                   echo "$RESULT"
               fi
           else
               echo "$RESULT"
           fi
           set +f
       fi
    else
       echo '.'
    fi
    ;;

#--------------------------------------------------------------
# execute
#--------------------------------------------------------------
"exe"|"execute"|"ex"|"e")

    READ_OPT=":hV"
    getOptions $*
    shift $?

    [[ $OPT_H = Y ]] && showUsage && exit 0
    [[ $OPT_VC = Y ]] && showVersion && exit 0

    ITEM=${1:-"0"} && shift > /dev/null
    EXE="`path $ITEM`"
    
    #----------------------------------------------------------
    # if there is something to be executed supposedly executable
    if [[ "$EXE" != "." ]]; then
    
        CNT=0
        while [[ -n $1 ]]
        do
            P[$CNT]="$1"
            shift
            PARAMS="$PARAMS "'"'"\${P[$CNT]}"'"'
            let CNT+=1
        done
        eval execute `echo $PARAMS`
    else
        echo "Err: No command to execute under this name" >&2
    fi
    ;;
#---------------------------------------------------------------
# here goes those other names which will be translated into exe name [params]
# example:  notify Message -> exe notify Message
#---------------------------------------------------------------
*)
    READ_OPT=":h"
    getOptions $*
    shift $?

    [[ $OPT_H = Y ]] && showUsage && exit 0

    CNT=0
    while [[ -n $1 ]]
    do
        P[$CNT]="$1"
        shift
        PARAMS="$PARAMS "'"'"\${P[$CNT]}"'"'
        let CNT+=1
    done
    eval exe $EXENAME `echo $PARAMS`
    ;;
esac

