#!/usr/bin/env fish

# Initialize the data directory based on
# https://wiki.archlinux.org/index.php/XDG_Base_Directory
set -q XDG_DATA_DIR; or set XDG_DATA_DIR "$HOME/.local/share"
set -q FISH_JOURNAL_DIR; or set FISH_JOURNAL_DIR "$XDG_DATA_DIR/fish_journal"

function __journal_entry_template
    echo "#"
    echo ""
    echo "tags: "
end

function __journal_file_name
    set -l d (date +"%G-%0m-%0d-%0k-%0M-%0S")

    echo "$FISH_JOURNAL_DIR/$d.md"
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

    set -l fname (__journal_file_name)
    touch "$fname"
    set -l template __journal_entry_template 
    "$template" >> "$fname"

    # Store template in temporary file for easy check
    # if user actually edited the default template.
    # If not, delete the entry again
    set -l tmpfile (mktemp)
    "$template" > "$tmpfile"

    if not test -n "$EDITOR" 
        echo '$EDITOR not set, exiting'
        exit 1
    end
    "$EDITOR" "$fname"

    if cmp "$fname" "$tmpfile"
        echo "You didn't change the default template, so I'll delete the entry again"
        rm "$fname"
    else
        echo "Created new journal entry $fname"
    end
end

function __journal_search
    # Call with either -t or --tags
    # Accepts multiple values separated with commas
    set -l options (fish_opt -s t -l tags -r --multiple-vals)
    argparse $options -- $argv

    if test -n "$_flag_t"
        set -l tags (string split "," "$_flag_t")
        set -l pattern (string join '|' $tags)
        for match in (grep -R -Ewo -- $pattern $FISH_JOURNAL_DIR | awk -F ':' '{ print $1 }' | sort | uniq)
            cat $match
            echo ""
        end
    end

    # TODO: Add search by title
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

switch "$argv[1]"
    case "tags"
        __journal_list_tags
    case "search"
        set -e argv[1]
        __journal_search $argv
    case ""
        __journal_new
end
