#!/usr/bin/env fish

# Initialize the data directory based on
# https://wiki.archlinux.org/index.php/XDG_Base_Directory
set -q XDG_DATA_DIR; or set XDG_DATA_DIR "$HOME/.local/share"
set -q FISH_JOURNAL_DIR; or set FISH_JOURNAL_DIR "$XDG_DATA_DIR/fish_journal"
set -q FISH_JOURNAL_EXTENSION; or set FISH_JOURNAL_EXTENSION ".md"

# Date format which can be sorted lexicographicically Means you can 
# sort dates by their character value. 2020 > 2019 then month 05 > 04, 
# and so on
set __journal_date_format "%Y-%m-%d %T"

# Override this function to pass your own template
set -q __journal_entry_template; 
or set __journal_entry_template (\
function __journal_entry_template
    echo ""
end)

# Takes a date string and formats it in a way which can be used for 
# lexicographic sorting. Works with BSD and GNU date.
function __journal_date_lexicographic
    # This kinda sorta detects if we're dealing with GNU or BSD date
    if date --version >/dev/null 2>&1
        echo (date -d $argv[1] +$__journal_date_format)
    else
        echo (date -j -f "%a %b %d %T %Z %Y" $argv[1] +$__journal_date_format)
    end
end

function __journal_dir_name
    echo $FISH_JOURNAL_DIR/(random 100000 1000000)
end

function __journal_list_entries_sorted
    set -l options \
        (fish_opt -s n -l number -r) \
        (fish_opt -s f -l filename-only) \
        (fish_opt -s F -l from -r) \
        (fish_opt -s U -l until -r)
    if not argparse -i $options -- $argv
        echo "failed to parse arguments" 1>&2
        return
    end

    set -l number_entries_to_show

    if set -q _flag_n
        set number_entries_to_show $_flag_n
    else
        set number_entries_to_show (count $argv)
    end

    set -l date_range_result

    if set -q _flag_n; and test $_flag_n -eq 0
        return
    end

    # Compare the date of each entry against the --from and --until values
    # by using "expr" and lexicographic comparison
    for v in $argv[1..$number_entries_to_show]
        set -l pass 1

        set -l date_entry (cat $v/date)

        # --from
        if set -q _flag_F
            # This kind of date usage doesn't work on MacOS since the -d
            # flag for BSD date does something completely different than in GNU
            set -l cmp_date (__journal_date_lexicographic $_flag_F)
            if not test (expr $cmp_date "<=" $date_entry) -ne 0
                set pass 0
            end
        end

        # --until
        if set -q _flag_U
            set -l cmp_date (__journal_date_lexicographic $_flag_U)

            if not test (expr $cmp_date ">=" $date_entry) -ne 0
                set pass 0
            end
        end

        if test $pass -ne 0
            set -a date_range_result $v
        end
    end

    # Sort the results in descending order based on the date in each 
    # entrys' "date" file. Use lexicographic sort thanks to the date format
    set -l sorted (for v in $date_range_result; printf '%s "%s"\n' $v (cat $v/date); end | sort -k2 -r | awk '{ print $1 }')

    for path in $sorted
        if set -q _flag_f
            for f in $path/*
                echo $f
            end
        else
            echo '--------------------'
            echo $path
            cat $path/date
            cat $path/title
            fold -s < $path/body
        end
    end
end

function __journal_new
    # Make sure directory exists and that it is a directory
    if not test -d "$FISH_JOURNAL_DIR"
        echo "Creating $FISH_JOURNAL_DIR to store journal entries"
        mkdir -p "$FISH_JOURNAL_DIR"
    end

    if test \( -d "$FISH_JOURNAL_DIR" \) -a \( -f "$FISH_JOURNAL_DIR" \)
        echo "$FISH_JOURNAL_DIR is a file, exiting"
        exit 1
    end

    set -l entry_dir (__journal_dir_name)

    if test -d $entry_dir
        echo "$entry_dir already exists!"
        echo "This is extremely rare, since these names"
        echo "are generated with the 'random' command."
        echo "Please just create a new entry one more time."
        echo "If the problem persists, please create an issue"
        echo "on https://github.com/cideM/fish-journal/"
        exit 1
    end
    mkdir -p "$entry_dir"

    set -l options \
        (fish_opt -s t -l tags -r --multiple-vals) \
        (fish_opt -s T -l title -r) \
        (fish_opt -s d -l date -r)

    argparse $options -- $argv
    if not argparse -i $options -- $argv
        echo "failed to parse arguments" 1>&2
        return
    end

    # Store date
    if set -q _flag_d
        __journal_date_lexicographic $_flag_d >$entry_dir/date
    else
        __journal_date_lexicographic (date) >$entry_dir/date
    end

    # Store tags
    if set -q _flag_t
        for tag in "$_flag_t"
            echo "$tag" >>"$entry_dir"/tags
        end
    else
        touch "$entry_dir"/tags
    end

    if set -q _flag_T
        echo "$_flag_T" >"$entry_dir"/title
    else
        touch "$entry_dir"/title
    end

    # Write template into new entry, which user will later on edit
    set -l entry_text "$entry_dir"/body
    set -l template __journal_entry_template
    "$template" >>"$entry_text"

    # Store template in temporary file so we can
    # easily compare the template with what the user
    # edited. If the user simply closed the editor
    # without making any changes, we can delete the
    # entry again.
    set -l tmpfile (mktemp)
    "$template" >"$tmpfile"

    if not set -q EDITOR
        exit 1
    end

    "$EDITOR" "$entry_text"

    # Check if files are different, meaning, check
    # if user actually made any changes to the template
    if cmp "$entry_text" "$tmpfile" >/dev/null
        echo "You didn't change the default template, so I'll delete the entry again"
        rm -r $entry_dir
    else
        echo "Created new journal entry $entry_text"
    end
end

function __journal_search
    set -l options \
        (fish_opt -s t -l tags -r --multiple-vals) \
        (fish_opt -s T -l title -r)
    argparse -i $options -- $argv
    if not argparse -i $options -- $argv
        echo "failed to parse arguments" 1>&2
        return
    end

    # For each category (tags, title), find all matches. Then return 
    # the intersection of the matches. That's how this search works in a 
    # nutshell and most of the code is plumbing and boilerplate since Fish 
    # (obviously) doesn't have set functions (union, intersection, etc). If 
    # a category is not defined, for example if the user did not supply 
    # tags to search, consider all files to match. So if we have one match 
    # for the given title, return the intersection of the title matches 
    # (one file) and the tag matches (all files).
    set -l tag_results $FISH_JOURNAL_DIR/*/tags

    if test (count $tag_results) -eq 0
        echo "You don't have any journal entries yet!"
        return
    end

    if set -q _flag_t
        for tag in $_flag_t
            set tag_results (grep -l "$tag" $tag_results)
        end
    end

    set -l title_results $FISH_JOURNAL_DIR/*/title

    if set -q _flag_T
        set title_results (grep -l "$_flag_T" $title_results)
    end

    # Remove the /title suffix so that we can compare matches from 
    # different categories by dirname
    set -l title_results_dirs
    for path in $title_results
        set -a title_results_dirs (dirname $path)
    end

    set -l results_dirs
    for path in $tag_results
        set -l dir (dirname $path)

        if contains $dir $title_results_dirs
            set -a results_dirs $dir
        end
    end

    if test -n "$results_dirs"
        __journal_list_entries_sorted $results_dirs $argv
    end
end

function __journal_list_tags
    cat $FISH_JOURNAL_DIR/*/tags
end

function __journal_list_titles
    cat $FISH_JOURNAL_DIR/*/title
end

function journal -a cmd -d "Fish journal"
    set -l options \
        (fish_opt -s h -l help)
    argparse -i $options -- $argv
    if not argparse -i $options -- $argv
        echo "failed to parse arguments" 1>&2
        return
    end

    if set -q _flag_h
        __journal_help
        return
    end
switch "$cmd"
        case tags
            __journal_list_tags
        case titles
            __journal_list_titles
        case search
            set -e argv[1]
            __journal_search $argv
        case new
            set -e argv[1]
            __journal_new $argv
        case \*
            set -e argv[1]
            __journal_help
    end
end

function __journal_help
    echo 'Usage:'
    echo 'journal help/--help/-h     Show this help'
    echo ''
    echo 'journal new                Open $EDITOR to create a new journal entry'
    echo '        -t/--tag   TAG     Can be passed multiple times'
    echo '                           Each passed value will be one tag of the new entry'
    echo '        -T/--title TITLE   Title for journal entry'
    echo '        -d/--date  DATE    Date to be used for date of entry'
    echo '                           Must be date with standard formatting'
    echo '                           Create journal entry for yesterday on MacOS/BSD:'
    echo '                           Example: journal -d (LANG=da_DK.iso_8859-1 date -v-1d)'
    echo ''
    echo '                           Using LANG has no effect, since the names in which'
    echo '                           date string components are written doesn\'t matter'
    echo '                           You just shouldn\'t change the order of the date components'    
    echo '                           Internally dates are reformatted anyway'
    echo '                           Also see --from help below'
    echo ''
    echo 'journal search             List journal entries (without options, list all entries)'
    echo '        -n/--number        Maximum number of entries to show'
    echo '        -f/--filename-only Show only the filenames instead of the entire entry'
    echo '                           Useful for piping the output into other programs'
    echo '        -F/--from DATE     Show only entries where date is greater than or equal to'
    echo '                           DATE. The value of DATE depends on whether you (want?)'
    echo '                           to use BSD date (MacOS) or GNU date (Linux).'
    echo ''
    echo '                           All entries since yesterday:'
    echo '                           BSD/MacOS: journal list --from (date -v-1d)'
    echo '                           GNU/Linux: journal list --from (date -d 'yesterday')'
    echo ''
    echo '                           Either way, please pass a DATE using the standard formatting'
    echo '        -U/--until DATE    Show only entries where date is less than or equal to'
    echo '                           DATE. For the description of DATE, please see help text for'
    echo '                           --from flag'
    echo '        -t/--tags TAG      Can be passed multiple times'
    echo '                           Show only entries which match all values passed as TAG'
    echo '                           Show all entries matching foo AND bar'
    echo '                           journal search -t foo -t bar'
    echo '        -T/--title TITLE   Show only entries whose title is contained in TITLE'
    echo '                           Show all entries where title includes foo'
    echo '                           journal search -T foo'
    echo ''
    echo 'Customziations:'
    echo 'You can customize the default template, meaning the text that will be'      
    echo 'shown when $EDITOR is opened. Just override __journal_entry_template, like so:'
    echo '$ function __journal_entry_template; echo "foo"; end; journal'
end
