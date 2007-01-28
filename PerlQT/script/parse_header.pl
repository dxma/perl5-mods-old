#! /usr/bin/perl -w

use strict;
#use English qw( -no_match_vars );

use Fcntl qw(O_CREAT O_WRONLY);
use Parse::RecDescent;

=head1 DESCIPTION

Parse specified CPP header file. Get all required information for
marshalling interface.

B<NOTE>: currently focus on typedef and class declaration mainly.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dongxu Ma

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

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
    print STDERR "passed!\n";
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
# CAUTION: the biggest asset here is we are working on a _VALID_ header
begin          : loop(s) eof 
eof            : /^\Z/
primitive_loop : 
    qt_macro(s)   { $return = $item[1] } 
  | typedef(s)    { $return = $item[1] }
  | comment(s)    { $return = $item[1] }
  | enum(s)       { $return = $item[1] }
  | template(s)   { $return = $item[1] }
  | class(s)      { $return = $item[1] }
  | function(s)   { $return = $item[1] }
  | expression(s) { $return = $item[1] }
# inside a class each primitive code block has to consider 
# accessibility keyword(s) in front of  
primitive_loop_inside_class : 
    qt_macro   { $return = $item[1] } 
  | typedef    { $return = $item[1] }
  | comment    { $return = $item[1] }
  | enum       { $return = $item[1] }
  | template   { $return = $item[1] }
  | class      { $return = $item[1] }
  | function   { $return = $item[1] }
  | expression { $return = $item[1] } 
loop           : primitive_loop | 
# keywords
keywords         : 
    keyword_class    | keyword_typedef | keyword_comment 
  | keyword_template | keyword_enum 
keyword_friend   : 'friend' 
keyword_class    : keyword_friend(?) ( 'class' | 'struct' ) 
keyword_typedef  : 'typedef'
keyword_comment  : '#'
keyword_template : 'template'
keyword_enum     : 'enum'
# primitive code blocks
comment   : 
  keyword_comment /.*?$/mio 
    { $return = $item[1]. " ". $item[2]   } 
    { print $item[1], ": ", $item[2], "\n" }
# FIXME: typedef anonymous enum|union|class
typedef   : 
  keyword_typedef /(?>[^;]+)/sio ';'  
    { $return = join(" ", @item[1 .. $#item-1])   }
    { print $item[1], ": ", join(" ", @item[2 .. $#item-1]), "\n" }
enum      : 
  keyword_enum enum_name enum_body variables ';'
    { $return = join(" ", @item[1 .. $#item-1])   }  
    { print $item[1], ": ", join(" ", @item[2 .. $#item-1]), "\n" }
# make sure it has no other structure delimiters
expression: 
    ( keywords | class_accessibility_content ) <commit> <reject>
  | expression_next_token ';'
    { $return = $item[1] } 
    { print "expression: ", $item[1], "\n" }
# container code blocks
template : 
  keyword_template '<' template_typename '>' template_body
    { $return = join(" ", @item[1 .. $#item])   } 
    { print $item[1], ": ", join(" ", @item[2 .. $#item]), "\n" }
class    : 
  keyword_class class_name class_inheritance class_body variables ';'
    { $return = join(" ", @item[1 .. $#item-1])   } 
    { print $item[1], ": ", join(" ", @item[2 .. $#item-1]), "\n" }
# a simple trap here 
# to prevent template function parsed as normal one
function : 
    keyword_template <commit> <reject>
  | function_header function_body
    { $return = $item[1]   } 
    { print "function: ", $item[1], "\n" }
# QT-specific macros
qt_macro : 
    'QT_BEGIN_HEADER' { $return = $item[1] } 
    { print $item[1], "\n" } 
  | 'QT_END_HEADER' { $return = $item[1] } 
    { print $item[1], "\n" } 
  | 'QT_MODULE' '(' next_end_bracket ')' 
    { $return = join(" ", @item[1 .. $#item]) } 
    { print $return, "\n" } 
  | 'Q_OBJECT' { $return = $item[1] } 
    { print $return, "\n" } 
  | 'Q_PROPERTY' '(' next_end_bracket ')' 
    { $return = join(" ", @item[1 .. $#item]) }
    { print $return, "\n" } 
  | 'Q_DECLARE_PRIVATE' '(' next_end_bracket ')' 
    { $return = join(" ", @item[1 .. $#item]) } 
    { print $return, "\n" } 
  | 'Q_DISABLE_COPY' '(' next_end_bracket ')' 
    { $return = join(" ", @item[1 .. $#item]) } 
    { print $return, "\n" } 
  | 'Q_PRIVATE_SLOT' '(' balanced_bracket(s) ')' 
    { $return = join(" ", $item[1], $item[2], @{$item[3]}, $item[4]) } 
    { print $return, "\n" } 
# functional code blocks
# internal actions
# CAUTION: might get dirty string which contains \t\n
#          strip hard return
# FIXME: \015 for MSWin32
next_begin_brace : 
  /(?>[^\{]+)/sio     { ( $return = $item[1] ) =~ s/\n//go }
next_end_brace : 
  /(?>[^\}]+)/sio     { ( $return = $item[1] ) =~ s/\n//go }
next_begin_or_end_brace : 
  /(?>[^\{\}]+)/sio   { ( $return = $item[1] ) =~ s/\n//go }
next_begin_angle_bracket : 
  /(?>[^\<]+)/sio     { ( $return = $item[1] ) =~ s/\n//go }
next_end_angle_bracket : 
  /(?>[^\>]+)/sio     { ( $return = $item[1] ) =~ s/\n//go }
next_begin_or_end_angle_bracket : 
  /(?>[^\<\>]+)/sio   { ( $return = $item[1] ) =~ s/\n//go }
next_equals : 
  /(?>[^\=]+)/sio     { ( $return = $item[1] ) =~ s/\n//go }
next_dot : 
  /(?>[^\,]+)/sio     { ( $return = $item[1] ) =~ s/\n//go }
next_dot_or_end_brace : 
  /(?>[^\,\}]+)/sio   { ( $return = $item[1] ) =~ s/\n//go } 
next_begin_bracket : 
  /(?>[^\(]+)/sio     { ( $return = $item[1] ) =~ s/\n//go }
next_end_bracket : 
  /(?>[^\)]+)/sio     { ( $return = $item[1] ) =~ s/\n//go }
next_begin_or_end_bracket : 
  /(?>[^\(\)]+)/sio   { ( $return = $item[1] ) =~ s/\n//go } 
next_begin_or_end_bracket_or_semicolon_or_begin_brace : 
  /(?>[^\(\)\;\{]+)/sio { ( $return = $item[1] ) =~ s/\n//go } 
next_bracket_or_brace_or_semicolon : 
  /(?>[^\(\)\{\}\;]+)/sio { ( $return = $item[1] ) =~ s/\n//go } 
next_semicolon : 
  /(?>[^\;]+)/sio     { ( $return = $item[1] ) =~ s/\n//go }
next_begin_brace_or_colon_or_semicolon : 
  /(?>[^\{\:\;]+)/sio { ( $return = $item[1] ) =~ s/\n//go }

blanced_bracket_next_token : 
    next_begin_or_end_bracket { $return = $item[1] } 
  | { $return = ''       } 
balanced_bracket : 
  blanced_bracket_next_token ( '(' balanced_bracket ')' 
    { $return = join(" ", @item[1 .. $#item]) } | { $return = '' } ) 
    { $return = join(" ", @item[1 .. $#item]) } 
  | { $return = ''       } 
# expression related
expression_next_token : 
  next_bracket_or_brace_or_semicolon { $return = $item[1] }
  | { $return = ''       } 

variables : next_semicolon { $return = $item[1] } | { $return = '' } 

# function related
# at least one '()' block should appear for a valid header
# trap other keywords to prevent mess
function_header       : 
    (   keyword_comment | keyword_class | keyword_enum 
      | keyword_typedef ) <commit> <reject>
  | function_header_block(s) { $return = join(" ", @{$item[1]}) } 
function_header_next_token : 
  next_begin_or_end_bracket_or_semicolon_or_begin_brace 
    { $return = $item[1] } 
  | { $return = ''       } 
function_header_block : 
  function_header_next_token '(' function_header_loop(s?) ')' 
    { $return = join(" ", $item[1], $item[2], @{$item[3]}, $item[4]) }
  | 'const' { $return = $item[1] } 
function_header_loop  : 
    function_header_next_token ( '(' function_header_loop ')' 
      { $return = join(" ", @item[1 .. $#item]) } 
    | { $return = '' } ) 
    { $return = join(" ", @item[1 .. $#item]) } 
  | { $return = '' } 
function_body         : 
    ';' { $return = '' }
  | '=' '0' ';' { $return = '' }
  | '{' function_body_block(s) '}' { $return = '' }
function_body_next_token : 
    next_begin_or_end_brace { $return = $item[1] }
  | { $return = ''       } 
function_body_block   : 
    function_body_next_token (  '{' function_body_block '}' | ) 
  | 

# enum related
enum_name          : 
    next_begin_brace { $return = $item[1] }
  | { $return = ''       } 
# enum_unit(s /,/) _NOT_ work here
enum_body          : 
  '{' enum_unit(s) '}'
  { $return = join(" ", @{$item[2]}) }
  #{ print "enum_body: ", $return, "\n" } 
enum_unit          : 
  next_dot_or_end_brace ( ',' | )
  { $return = (split /=/, $item[1])[0] }
  #{ print "enum_unit: $return\n" } 

# template related
template_typename  : 
    next_end_angle_bracket { $return = $item[1] } 
  | { $return = ''       }
template_body      : 
    class { $return = $item[1] }
  | function { $return = $item[1] } 

# class related
class_name          : 
    next_begin_brace_or_colon_or_semicolon { $return = $item[1] } 
    #{ print "class_name: ", $item[1], "\n" } 
  | { $return = ''       } 
# FIXME: multiple inherit
class_inheritance   : 
    ':' next_begin_brace { $return = $item[2] }
    #{ print "class_inheritance: ", $item[2], "\n" }
  | { $return = ''       }
# class_body_content(s?) _NOT_ work here
class_body          : 
    '{' '}' { $return = ''       }
  | '{' class_body_content(s) '}' 
    { $return = join(" ", @{$item[2]}) } 
  | { $return = ''       } 
class_body_content  : 
    class_accessibility primitive_loop_inside_class 
    { $return = join(" ", $item[1], $item[2]) } 
    #{ print "class_body_content: ", $return, "\n" }
  | { $return = ''       } 
    #{ print "class_body_content: NULL\n" } 
class_accessibility : 
    ( class_accessibility_content(?) qt_accessibility_content(?) ':' 
      { $return = join(" ", @{$item[1]}, @{$item[2]}) } )
    { $return = $item[1] }
  | { $return = ''       }
qt_accessibility_content : 
  ( 'Q_SIGNALS' | 'Q_SLOTS' ) { $return = $item[1] } 
class_accessibility_content : 
  ( 'public' | 'private' | 'protected' ) { $return = $item[1] } 
