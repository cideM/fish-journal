#!/usr/bin/env fish

# Initialize the data directory based on
# https://wiki.archlinux.org/index.php/XDG_Base_Directory
set -q XDG_DATA_DIR; or set XDG_DATA_DIR "$HOME/.local/share"
set -q FISH_JOURNAL_DIR; or set FISH_JOURNAL_DIR "$XDG_DATA_DIR/fish_journal"

set __fish_journal_date_format "%Y-%m-%d %T"

function __journal_entry_template
    echo ""
end

# TODO: Usage
# TODO: name functions etc in the same way not some fish__ and others __jorunal
function __journal_dir_name
    echo "$FISH_JOURNAL_DIR"/(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 10)
end

function __journal_list_entries_sorted 
    set -l options                       \
        (fish_opt -s n -l number -r)     \
        (fish_opt -s f -l filename-only) \
        (fish_opt -s F -l from -r)       \
        (fish_opt -s U -l until -r)
    argparse -i $options -- $argv
    
    set -l number_entries_to_show
    
    if set -q _flag_n
        set number_entries_to_show $_flag_n
    else
        set number_entries_to_show (count $argv)
    end

    set -l date_range_result 

    # Compare the date of each entry against the --from and --until values
    # by using "expr" and lexicographic comparison
    for v in $argv[1..$number_entries_to_show]
        set -l pass 1

        set -l date_entry (cat $v/date)

        # --from
        if set -q _flag_F
            set -l cmp_date (date -d $_flag_F +$__fish_journal_date_format)

            if not test (expr $cmp_date "<=" $date_entry) -ne 0
                set pass 0
            end
        end

        # --until
        if set -q _flag_U
            set -l cmp_date (date -d $_flag_U +$__fish_journal_date_format)

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
            cat $path/body
        end
    end
end

function __journal_list
    __journal_list_entries_sorted $FISH_JOURNAL_DIR/* $argv
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
        exit 1
    end

    "$EDITOR" "$entry_text"

    # Check if files are different, meaning, check
    # if user actually made any changes to the template
    if cmp "$entry_text" "$tmpfile" > /dev/null
        echo "You didn't change the default template, so I'll delete the entry again"
        rm -r $entry_dir
    else
        echo "Created new journal entry $entry_text"
    end
end

function __journal_search
    set -l options                                 \
        (fish_opt -s t -l tags -r --multiple-vals) \
        (fish_opt -s T -l title -r)
    argparse -i $options -- $argv

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

    if test -n "$results_dirs"
        # Passing $argv here will include the options
        # that were already parsed. According to the Fish
        # docs this shouldn't be the case. TODO: Create bug report
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
    switch "$cmd"
        case tags
            __journal_list_tags
        case titles
            __journal_list_titles
        case search
            __journal_search $argv[2..-1]
        case list
            __journal_list $argv[2..-1]
        case \*
            __journal_new $argv[2..-1]
    end
end
#!/usr/bin/env fish
