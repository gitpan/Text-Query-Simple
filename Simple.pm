package Text::Query::Simple;

BEGIN {
  require 5.005;
}

$VERSION=0.03;

use strict;
use re qw/eval/;

# class data is temporary only
my ($parse_error,@tokens,$token);

sub new {
  my $class=shift;
  my $self={};
  bless $self,$class;
  return $self if !@_;
  return $self->prepare(@_);
}

sub prepare {
  my $self=shift;
  my $qstring=shift;
  my ($re,$t,$type,$i,$mc,$m,$weight);
  $self->{parseopts}={-regexp=>0,-litspace=>0,-case=>0,-whole=>0,@_};
  parse_tokens($self,$qstring);
  $parse_error=0;
  $self->{ws}=0;
  $re=($self->{parseopts}{-case})?'':'(?i)';
  $mc=$i=0;
  foreach $t (@tokens) {
    $type=($t=~s/([-+\e])//)?$1:'';   
    $weight=($t=~s/\((\d+)\)$//)?$1:1;
    if (!$self->{parseopts}{-regexp}) {
      $t=quotemeta($t);
      $t=~s/\\\*/\\w*/g;
    } 
    $t=~s/\\? +/\\s+/g if !$self->{parseopts}{-litspace};
    $t="\\b$t\\b" if $self->{parseopts}{-whole};
    $t="(?:$t)" if $self->{parseopts}{-regexp};
    $m=0;
    if ($type eq '-') {
      $m=(~0);
    } elsif ($type eq '+') {
      $m=1<<($mc++);
      $self->{ws}|=$m;
    }
    $re.='|' if $i++;
    $re.=sprintf("%s(?{[%d,%d]})",$t,~$m,$weight);
  }    
  $parse_error=1 if ($i==0 or $mc>31);
  return undef if $parse_error;
  $self->{matchexp}=qr/$re/s;
  return $self;  
}

sub match {
  my $self=shift;
  my @ra;
  return $self->matchscalar(shift || $_) if @_<=1 && ref($_[0]) ne 'ARRAY';
  my $pa=(@_==1 && ref($_[0]) eq 'ARRAY')?shift:\@_;
  if (ref($pa->[0]) eq 'ARRAY') {
    @ra=map {[@$_,$self->matchscalar($_->[0])]} @$pa;
  } else {
    @ra=map {[$_,$self->matchscalar]} @$pa;
  }
  @ra=sort {$b->[$#{@$b}] <=> $a->[$#{@$a}]} @ra;
  return wantarray?@ra:\@ra;
}

sub matchscalar {
  my $self=shift;
  my $target=(shift || $_);
  my $cnt;
  my $ws=$self->{ws};
  while ($target=~/$self->{matchexp}/g) {
    return 0 if !$^R->[0];
    $cnt+=$^R->[1];
    $ws&=$^R->[0];
  }
  return $ws?0:$cnt;
}

sub parse_tokens {
  local($^W) = 0;
  my $self=shift;
  my($line) = @_;
  my($quote, $quoted, $unquoted, $delim, $word);

  @tokens=();
  while (length($line)) {
    ($quote, $quoted, undef, $unquoted, $delim, undef) =
      $line =~ m/^(["'])                 # a $quote
                ((?:\\.|(?!\1)[^\\])*)    # and $quoted text
                \1 		       # followed by the same quote
                ([\000-\377]*)	       # and the rest
	       |                       # --OR--
                ^((?:\\.|[^\\"'])*?)    # an $unquoted text
	        (\Z(?!\n)|\s+|(?!^)(?=["'])) # plus EOL, delimiter, or quote
                ([\000-\377]*)	       # the rest
	       /ix;		       # extended layout

    return() unless( $quote || length($unquoted) || length($delim));
    $line = $+;
    $unquoted=~s/^\s+//;
    $unquoted=~s/\s+$//;
    $word .= defined $quote?(length($word)?$quoted:"\e$quoted"):$unquoted;
    push(@tokens,$word) if length ($word) and (length($delim) or !length($line));
    undef $word if length $delim;
  }
}

1;
__END__

=head1 NAME

Text::Query::Simple - Match text against simple query expression and return relevance value for ranking

=head1 SYNOPSIS

    use Text::Query::Simple;
    
    # Constructor
    $query = Text::Query::Simple->new([QSTRING] [OPTIONS]);

    # Methods
    $query->prepare(QSTRING [OPTIONS]);
    $query->match([TARGET]);
    $query->matchscalar([TARGET]);

=head1 DESCRIPTION

This module provides an object that tests a string or list of strings 
against a query expression similar to an AltaVista "simple  query" and 
returns a "relevance value."  Elements of the query expression may be 
regular expressions or literal text, and may be assigned weights.

Query expressions are compiled into an internal form when a new object is 
created or the C<prepare> method is called; they are not recompiled on each 
match.

Query expressions consist of words (sequences of non-whitespace), regexps 
or phrases (quoted strings) separated by whitespace.  Words or phrases 
prefixed with a C<+> must be present for the expression to match; words or 
phrases prefixed with a C<-> must be absent for the expression to match.

A successful match returns a count of the number of times any of the words 
(except ones prefixed with C<->) appeared in the text.  This type of result 
is useful for ranking documents according to relevance.

Words or phrases may optionally be followed by a number in parentheses (no 
whitespace is allowed between the word or phrase and the parenthesized 
number).  This number specifies the weight given to the word or phrase; it 
will be added to the count each time the word or phrase appears in the 
text.  If a weight is not given, a weight of 1 is assumed.

=head1 EXAMPLES

  use Text::Query::Simple;
  my $q=new Text::Query::Simple('+hello world');
  die "bad query expression" if not defined $q;
  $count=$q->match;
  ...
  $q->prepare('goodbye adios -"ta ta",-litspace=>1);
  #requires single space between the two ta's
  if ($q->match($line,-case=>1)) {
  #doesn't match "Goodbye"
  ...
  $q->prepare('\\bintegrate\\b',-regexp=>1);
  #won't match "disintegrated"
  ...
  $q->prepare('information(2) retrieval');
  #information has twice the weight of retrieval

=head1 CONSTRUCTOR

=over 4

=item new ([QSTRING] [OPTIONS])

This is the constructor for a new Text::Query::Simple object.  If a 
C<QSTRING> is given it will be compiled to internal form.

C<OPTIONS> are passed in a hash like fashion, using key and value pairs.
Possible options are:

B<-case> - If true, do case-sensitive match.

B<-litspace> - If true, match spaces (except between operators) in 
C<QSTRING> literally.  If false, match spaces as C<\s+>.

B<-regexp> - If true, treat patterns in C<QSTRING> as regular expressions 
rather than literal text.

B<-whole> - If true, match whole words only, not substrings of words.

The constructor will return C<undef> if a C<QSTRING> was supplied and had 
illegal syntax.

=back

=head1 METHODS

=over 4

=item prepare (QSTRING [OPTIONS])

Compiles the query expression in C<QSTRING> to internal form and sets any 
options (same as in the constructor).  C<prepare> may be used to change 
the query expression and options for an existing query object.  If 
C<OPTIONS> are omitted, any options set by a previous call to the 
constructor or C<prepare> remain in effect.

This method returns a reference to the query object if the syntax of the 
expression was legal, or C<undef> if not.

=item match ([TARGET])

If C<TARGET> is a scalar, C<match> returns the number of words in the 
string specified by C<TARGET> that match the query object's query 
expression.  If C<TARGET> is not given, the match is made against C<$_>.

If C<TARGET> is an array, C<match> returns a list of references to 
anonymous arrays consisting of each element followed by its match count.  
The list is sorted in descending order by match count.  If the elements of 
C<TARGET> were anonymous arrays, the match count is appended to each 
element.  This allows arbitrary information (such as a filename) to be 
associated with each element.

If C<TARGET> is a reference to an array, C<match> returns a reference to 
a sorted list of matching items, with counts, for all elements.  

=item matchscalar ([TARGET])

Behaves just like C<MATCH> when C<TARGET> is a scalar or is not given.  
Slightly faster than C<MATCH> under these circumstances.

=back

=head1 RESTRICTIONS

This module requires Perl 5.005 or higher due to the use of evaluated
expressions in regexes

=head1 AUTHOR

Eric Bohlman (ebohlman@netcom.com)

=head1 CREDITS

The parse_tokens routine was adapted from the parse_line routine in 
Text::Parsewords.

=head1 COPYRIGHT

Copyright (c) 1998 Eric Bohlman. All rights reserved.
This program is free software; you can redistribute and/or modify
it under the same terms as Perl itself.
=cut
