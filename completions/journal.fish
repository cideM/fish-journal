# List all commands, useful for the -n option of the complete function
set -l commands tags search titles new help

# Disable file completion
complete -c journal -f

# Command completion
complete -c journal -n "not __fish_seen_subcommand_from $commands" -a "tags" -d "list all tags" 
complete -c journal -n "not __fish_seen_subcommand_from $commands" -a "titles" -d "list all titles" 
complete -c journal -n "not __fish_seen_subcommand_from $commands" -a "new" -d "create a new entry" 
complete -c journal -n "not __fish_seen_subcommand_from $commands" -a "help" -d "show help and usage" 
complete -c journal -n "not __fish_seen_subcommand_from $commands" -a "search" -d "search journal entries" 

# Switch/options completion
complete -c journal -s h -l help            -d "Help"
complete -c journal -s t -l tags            -n "__fish_seen_subcommand_from search new" -d "Tags" -a "(journal tags)"   -r -f
complete -c journal -s T -l title           -n "__fish_seen_subcommand_from search new" -d "Title" -a "(journal titles)"  -r -f
complete -c journal -s d -l date            -n "__fish_seen_subcommand_from new"        -d "Entry date"  -r
complete -c journal -s f -l "filename-only" -n "__fish_seen_subcommand_from search"     -d "list only filenames"
complete -c journal -s n -l "number"        -n "__fish_seen_subcommand_from search"     -d "max entries to show" -r
complete -c journal -s F -l "from"          -n "__fish_seen_subcommand_from search"     -d "show entries where date is greater than" -r
complete -c journal -s F -l "until"         -n "__fish_seen_subcommand_from search"     -d "show entries where date is lower than" -r

