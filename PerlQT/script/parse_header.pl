#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );

use Fcntl qw(O_CREAT O_WRONLY);
use Parse::RecDescent;

=head1 DESCIPTION

Parse specified CPP header file. Get all required information for
marshalling interface.

B<NOTE>: currently focus on typedef and class declaration mainly.

=cut

# Global flags 
# unless undefined, report fatal errors
#$::RD_ERRORS = 1;
# unless undefined, also report non-fatal problems
#$::RD_WARN = 1;
# if defined, also suggestion remedies
$::RD_HINT = 1;
# if defined, also trace parsers' behaviour
#$::RD_TRACE = 1;
# if defined, generates "stubs" for undefined rules
#$::RD_AUTOSTUB = 1;
# if defined, appends specified action to productions
#$::RD_AUTOACTION = 1;

sub usage {
    print STDERR << "EOU";
usage: $0 <path_to_blah.h> [<path_to_result>]
EOU
    exit 1;
}

sub main {
    usage() unless @ARGV;
    
    my ( $in, $out ) = @ARGV;
    die "file not found: $!" unless -f $in;
    my $source;
    local ( *OUT );
    
    my $grammar = do { local $/; <DATA> };
    my $parser = Parse::RecDescent::->new($grammar);
    
    {
        local ( *IN );
        open IN, '<', $in or die "cannot open file: $!";
        local $/;
        $source = <IN>;
        close IN or warn "cannot close file: $!";
    }
    if (defined $out) {
        die "file not found: $!" unless -f $out;
        sysopen OUT, $out, O_CREAT|O_WRONLY or 
          die "cannot open file: $!";
    }
    else {
        *OUT = *STDOUT;
    }
    
    #print STDERR $source;
    my $rc = $parser->begin($source);
    
    close OUT or warn "cannot write to file: $!" unless 
      fileno(OUT) == fileno(STDOUT);
    unlink $out if not defined $rc and defined $out and -f $out;
    exit 0;
}

main(@ARGV);
__DATA__
# focus on:
# Level 1: class, typedef, function, enum, union
# Level 2: template
# 
# which are relavant to make binding
# loop structure
begin          : loop 
primitive_loop : typedef(s)
               | comment(s)
               | enum(s)
               | function(s)
               | template(s)
               | class(s)
loop           : primitive_loop loop
# keywords
keyword_class    : 'class'
keyword_typedef  : 'typedef'
keyword_comment  : '#'
keyword_template : 'template'
keyword_enum     : 'enum'
keyword_union    : 'union'
# primitive code blocks
comment  : keyword_comment /.*?$/mio 
           { print $item[1], " ", $item[2], "\n" }
# FIXME: typedef anonymous enum|union|class
typedef  : keyword_typedef /(?>[^;]+)/sio ';'  
           { print join(" ", @item[1 .. $#item]), "\n" }
enum     : keyword_enum enum_name enum_body ';'
           { print join(" ", @item[1 .. $#item]), "\n" } 
# container code blocks
template : keyword_template '<' template_typename '>' template_body
           { print join(" ", @item[1 .. $#item]), "\n" }
class    : keyword_class class_name class_inheritance class_body ';'
           { print join(" ", @item[1 .. 3]), "\n" }
function : until_begin_bracket '(' until_end_bracket ')' function_body
           { print join(" ", @item[1 .. $#item-1]), "\n" }
# functional code blocks
# internal actions
until_begin_brace         : /(?>[^\{]+)/sio
                            { $return = $item[1] }
until_end_brace           : /(?>[^\}]+)/sio
                            { $return = $item[1] }
until_begin_angle_bracket : /(?>[^\<]+)/sio
                            { $return = $item[1] }
until_end_angle_bracket   : /(?>[^\>]+)/sio
                            { $return = $item[1] }
until_equals              : /(?>[^\=]+)/sio
                            { $return = $item[1] }
until_dot                 : /(?>[^\,]+)/sio
                            { $return = $item[1] }
until_begin_bracket       : /(?>[^\(]+)/sio
                            { $return = $item[1] }
until_end_bracket         : /(?>[^\)]+)/sio 
                            { $return = $item[1] }
until_colon               : /(?>[^\;]+)/sio
                            { $return = $item[1] }

# function related
function_body         : '{' function_body_content '}' 
                      | ';'
# FIXME: recursive
function_body_content : until_end_brace

# enum related
# FIXME
enum_name          : until_begin_brace
                     { $return = $item[1] }
enum_body          : '{' enum_unit(s /,/) '}'
enum_unit          : ( ...',' until_dot ) 
                     { $return = (split /=/, $item[1])[0] }
                   | until_end_brace 
                     { $return = (split /=/, $item[1])[0] }

# template related
template_typename  : until_end_angle_bracket 
                     { $return = $item[1] } 
                   |                
                     { $return = ''       }
template_body      : class | function

# class related
# FIXME
class_name          : ( ...'{' until_begin_brace ) 
                      { $return = $item[1] } 
                    | until_colon 
                      { $return = $item[1] } 
class_inheritance   : { $return = ''       }
class_body          : ( '{' class_body_content '}' )
                      { $return = 'class_body_content' }
                    | 
                      { $return = ''       } 
class_body_content  : class_accessibility primitive_loop
                      class_body_content
class_accessibility : ( 'public' | 'private' | 'protected' ) ':'
                      { $return = $item[1] }
                    | 
                      { $return = ''       }
