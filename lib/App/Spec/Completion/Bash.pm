use strict;
use warnings;
package App::Spec::Completion::Bash;

use base 'App::Spec::Completion';

sub generate_completion {
    my ($self, %args) = @_;
    my $spec = $self->spec;
    my $name = $spec->name;


    my $completion_outer = $self->completion_commands(
        commands => $spec->commands,
        options => $spec->options,
        level => 1,
    );

    my $body = <<"EOM";
#!bash

# http://stackoverflow.com/questions/7267185/bash-autocompletion-add-description-for-possible-completions

_$name() \{

    COMPREPLY=()
    local cur=\$\{COMP_WORDS[\$COMP_CWORD]\}
#    echo "COMP_CWORD:\$COMP_CWORD cur:\$cur" >>/tmp/comp

$completion_outer
\}

_${name}_compreply() \{
    IFS=\$'\\n' COMPREPLY=(\$(compgen -W "\$1" -- \$\{COMP_WORDS\[COMP_CWORD\]\}))
    if [[ \$\{#COMPREPLY[*]\} -eq 1 ]]; then #Only one completion
        COMPREPLY=( \$\{COMPREPLY[0]%% -- *\} ) #Remove ' -- ' and everything after
    fi
\}

complete -o default -F _$name $name
EOM
    return $body;
}

sub completion_commands {
    my ($self, %args) = @_;
    my $spec = $self->spec;
    my $name = $spec->name;
    my $commands = $args{commands};
    my $level = $args{level};
    my $indent = "    " x $level;

    my @commands = map {
        my $summary = $commands->{ $_ }->summary;
        length $summary ? "$_ -- " . $summary : $_
    } sort keys %$commands;
    my $cmds = join q{"$'\\n'"}, @commands;

    my $subc = <<"EOM";
$indent# subcmds
${indent}case \$\{COMP_WORDS\[$level\]\} in
EOM
    for my $name (sort keys %$commands) {
        $subc .= <<"EOM";
${indent}  $name)
EOM
        my $spec = $commands->{ $name };
        my $subcommands = $spec->subcommands;
        my $parameters = $spec->parameters;
        my $options = $spec->options;
        if (keys %$subcommands) {
            my $comp = $self->completion_commands(
                commands => $subcommands,
                options => $spec->options,
                level => $level + 1,
            );
            $subc .= $comp;
        }
        elsif (@$parameters or @$options) {
            $subc .= $self->completion_parameters(
                parameters => $parameters,
                options => $options,
                level => $level + 1,
            );
        }
        $subc .= <<"EOM";
${indent}  ;;
EOM
    }
    $subc .= <<"EOM";
${indent}esac
EOM

    my $completion = <<"EOM";
${indent}case \$COMP_CWORD in

${indent}$level)
${indent}    _${name}_compreply "$cmds"

${indent};;
${indent}*)
$subc
${indent};;
${indent}esac
EOM
    return $completion;
}

sub completion_parameters {
    my ($self, %args) = @_;
    my $spec = $self->spec;
    my $appname = $spec->name;
    my $parameters = $args{parameters};
    my $options = $args{options};
    my $level = $args{level};
    my $indent = "    " x $level;

    my $comp = <<"EOM";
${indent}case \$COMP_CWORD in
EOM

    for my $i (0 .. $#$parameters) {
        my $param = $parameters->[ $i ];
        my $name = $param->name;
        my $num = $level + $i;
        $comp .= $indent . "$num)\n";
        $comp .= $self->completion_parameter(
            parameter => $param,
            level => $level + 1,
        );
        $comp .= $indent . ";;\n";
    }

    if (@$options) {
        my $num = $level + @$parameters;
        $comp .= $indent . "*)\n";

        my @comp_options;
        my @comp_values;
        my $comp_value = <<"EOM";
${indent}case \$\{COMP_WORDS[\$COMP_CWORD-1]\} in
EOM
        for my $i (0 .. $#$options) {
            my $opt = $options->[ $i ];
            my $name = $opt->name;
            my $type = $opt->type;
            my $summary = $opt->description;
            my $aliases = $opt->aliases;
            my @names = ($name, @$aliases);
            my @option_strings;
            for my $n (@names) {
                my $dash = length $n > 1 ? "--" : "-";
                my $option_string = "$dash$n";
                my $string = length $summary
                    ? qq{'$option_string -- $summary'}
                    : qq{'$option_string'};
                push @option_strings, $option_string;
                push @comp_options, $string;
            }

            $comp_value .= <<"EOM";
${indent}  @{[ join '|', @option_strings ]})
EOM
            if (ref $type) {
                if (my $list = $type->{enum}) {
                    my @list = map { s/ /\\ /g; "'$_'" } @$list;
                    local $" = q{"$'\\n'"};
                    $comp_value .= <<"EOM";
${indent}    _${appname}_compreply "@list"
EOM
                }
            }
            elsif ($type eq "bool") {
            }
            elsif ($type eq "file" or $type eq "dir") {
            }
            $comp_value .= $indent . "  ;;\n";
        }

        {
            local $" = q{"$'\\n'"};
            $comp .= <<"EOM";
$comp_value
${indent}  *)
${indent}    _${appname}_compreply "@comp_options"
${indent}  ;;
${indent}esac
EOM
        }
        $comp .= $indent . ";;\n";
    }

    $comp .= $indent . "esac\n";
}

sub completion_parameter {
    my ($self, %args) = @_;
    my $spec = $self->spec;
    my $name = $spec->name;
    my $param = $args{parameter};
    my $level = $args{level};
    my $indent = "    " x $level;

    my $comp = '';

    my $type = $param->type;
    if (ref $type) {
        if (my $list = $type->{enum}) {
        local $" = q{"$'\\n'"};
        $comp = <<"EOM";
${indent}    _${name}_compreply "@$list"
EOM
        }
    }
    elsif ($type eq "file" or $type eq "dir") {
    }
    return $comp;
}


1;
