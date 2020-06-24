# Fish Journal :fish:

A small (362 LOC as measured with `tokei`) CLI tool for keeping a journal or diary, written in Fish, tested on both MacOS and Linux.

```fish
$ fisher add cideM/fish-journal
$ journal new -T "This is a title" -t some -t tags
Created new journal entry /some/path/123456/body
$ journal search
--------------------
/Users/foo/.local/share/fish_journal/983220.md
2020-06-20 08:49:12
This is a title
whatever you entered with $EDITOR when you called `journal new`
```

## Usage

[![asciicast](https://asciinema.org/a/25ACAApawE5aH79hjd4c3QtZs.svg)](https://asciinema.org/a/25ACAApawE5aH79hjd4c3QtZs)

Be sure to check out the help `journal help`!

```text
journal help/--help/-h     Show this help

journal new                Open $EDITOR to create a new journal entry
        -t/--tag   TAG     Can be passed multiple times
                           Each passed value will be one tag of the new entry
        -T/--title TITLE   Title for journal entry
        -d/--date  DATE    Date to be used for date of entry
                           Must be date with standard formatting
                           Create journal entry for yesterday on MacOS/BSD:
                           Example: journal -d (LANG=da_DK.iso_8859-1 date -v-1d)

                           Using LANG has no effect, since the names in which
                           date string components are written doesn't matter
                           You just shouldn't change the order of the date components    
                           Internally dates are reformatted anyway
                           Also see --from help below

journal search             List journal entries (without options, list all entries)
        -n/--number        Maximum number of entries to show
        -f/--filename-only Show only the filenames instead of the entire entry
                           Useful for piping the output into other programs
        -F/--from DATE     Show only entries where date is greater than or equal to
                           DATE. The value of DATE depends on whether you (want?)
                           to use BSD date (MacOS) or GNU date (Linux).

                           All entries since yesterday:
                           BSD/MacOS: journal list --from (date -v-1d)
                           GNU/Linux: journal list --from (date -d yesterday)

                           Either way, please pass a DATE using the standard formatting
        -U/--until DATE    Show only entries where date is less than or equal to
                           DATE. For the description of DATE, please see help text for
                           --from flag
        -t/--tags TAG      Can be passed multiple times
                           Show only entries which match all values passed as TAG
                           Show all entries matching foo AND bar
                           journal search -t foo -t bar
        -T/--title TITLE   Show only entries whose title is contained in TITLE
                           Show all entries where title includes foo
                           journal search -T foo
```

## Customziation

### Default Template 

Set the text that will be shown when $EDITOR is opened.  Just override `__journal_entry_template`, like so: 
```fish
$ function __journal_entry_template; echo "foo"; end; journal
```

### Default File Extension

Set `FISH_JOURNAL_EXTENSION`, `set -x FISH_JOURNAL_EXTENSION ".md"`

### Default Directory

Set `FISH_JOURNAL_DIR`, `set -x FISH_JOURNAL_DIR ~/my_journal`

## FAQ

### How does the whole `date` stuff work?

As a small and focused shell script, some things need to be outsourced to other
commands. One such area is handling dates. It's up to you to pass a valid date
string to `journal`, which can then be interpreted, and reformatted, through
something like this:

```fish
# GNU
date -d $YOUR_DATE +"%Y-%m-%d %T"

# BSD
date -j -f "%a %b %d %T %Z %Y" $YOUR_DATE +"%Y-%m-%d %T"
```

The above code will take your date and reformat it so it's easy to sort
lexicographically. For example, to show all entries since yesterday with BSD
date (MacOS), you can run `journal search --from (date -v-1d)`.

### How can I delete all journal entries?

Easiest would be to just delete the root folder of your journal. The default is
`"$XDG_DATA_DIR/fish_journal"` and `XDG_DATA_DIR` defaults to
`"$HOME/.local/share"`. Alternatively, you can leverage the `-f` flag, which
will return filenames of entries instead of the content. This snippet deletes
all entries without the deleting the journal root folder:

```fish 
journal search -f | while read -la v; rm -r (dirname $v) 2>/dev/null; end 
```

### How can I customize the template, file extension and base folder?

See 'Customization' above

## TODO

- [ ] Add option for only showing titles
