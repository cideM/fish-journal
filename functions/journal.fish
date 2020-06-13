#!/usr/bin/env fish

# Initialize the data directory based on
# https://wiki.archlinux.org/index.php/XDG_Base_Directory
set -q XDG_DATA_DIR; or set XDG_DATA_DIR "$HOME/.local/share"
set -q FISH_JOURNAL_DIR; or set FISH_JOURNAL_DIR "$XDG_DATA_DIR/fish_journal"

set __fish_journal_date_format "%Y-%m-%d %T"

function __journal_entry_template
    echo ""
end

# TODO: Add -T --title option
# TODO: Add -d --date option (use human language insofar date supports it)
# TODO: Editor opens only for body of entry now
# TODO: store 4 files: title, body, tags, date. Folder name is date + lower cased and escaped title probably style=var (check man string escape)
function __journal_dir_name
    echo "$FISH_JOURNAL_DIR"/(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 10)
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
    mkdir -p "$entry_dir"

    set -l options                              \
        (fish_opt -s t -l tags -r --multiple-vals) \
        (fish_opt -s T -l title -r)                \
        (fish_opt -s d -l date -r)
    argparse $options -- $argv

    # Store date
    if set -q _flag_d
        echo (date -u -d "$_flag_d" +$__fish_journal_date_format) > $entry_dir/date
    else
        echo (date -u +$__fish_journal_date_format) > $entry_dir/date
    end

    # Store tags
    if set -q _flag_t
        for tag in "$_flag_t"
            echo "$tag" >> "$entry_dir"/tags
        end
    else
        touch "$entry_dir"/tags
    end

    if set -q _flag_T
        echo "$_flag_T" > "$entry_dir"/title
    else
        touch "$entry_dir"/title
    end

    # Write template into new entry, which user will later on edit
    set -l entry_text "$entry_dir"/body
    set -l template __journal_entry_template 
    "$template" >> "$entry_text"

    # Store template in temporary file so we can
    # easily compare the template with what the user
    # edited. If the user simply closed the editor
    # without making any changes, we can delete the
    # entry again.
    set -l tmpfile (mktemp)
    "$template" > "$tmpfile"

    if not set -q EDITOR 
        echo '$EDITOR not set, exiting'
        exit 1
    end

    "$EDITOR" "$entry_text"

    # Check if files are different, meaning, check
    # if user actually made any changes to the template
    if cmp "$entry_text" "$tmpfile" > /dev/null
        echo "You didn't change the default template, so I'll delete the entry again"
        rm "$entry_text"
    else
        echo "Created new journal entry $entry_text"
    end
end

function __journal_search
    set -l options                                 \
        (fish_opt -s t -l tags -r --multiple-vals) \
        (fish_opt -s T -l title -r)
    argparse $options -- $argv

    # For each category (tags, title), find all matches. Then return 
    # the intersection of the matches. That's how this search works in a 
    # nutshell and most of the code is plumbing and boilerplate since Fish 
    # (obviously) doesn't have set functions (union, intersection, etc). If 
    # a category is not defined, for example if the user did not supply 
    # tags to search, consider all files to match. So if we have one match 
    # for the given title, return the intersection of the title matches 
    # (one file) and the tag matches (all files).
    set -l tag_results $FISH_JOURNAL_DIR/*/tags

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

    # Sort the results in descending order based on the date in each 
    # entrys' "date" file. Use lexicographic sort thanks to the date format
    set -l sorted (for v in $results_dirs; printf '%s "%s"\n' $v (cat $v/date); end | sort -k2 -r | awk '{ print $1 }')
    
    for path in $sorted
        echo '--------------------'
        echo $path
        cat $path/date
        cat $path/title
        cat $path/body
    end
end

function __journal_list_tags
    # Gather tags but without the leading 'tags: '
    # and skip duplicates
    set -l tags
    for line in (grep -hR "tags:" "$FISH_JOURNAL_DIR")
        for t in (string split " " "$line")
            if not test (string trim "$t") = "tags:";
                and not contains $t $tags
                set -a tags "$t"
            end
        end
    end

    for t in $tags
        echo $t
    end
end

function journal -a cmd -d "Fish journal"
    switch "$cmd"
        case tags
            __journal_list_tags
        case search
            __journal_search $argv
        case \*
            __journal_new $argv
    end
end

