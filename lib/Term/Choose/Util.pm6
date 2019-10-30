use v6;
unit class Term::Choose::Util:ver<1.3.0>;

use Term::Choose;
use Term::Choose::LineFold;
use Term::Choose::Screen;

has %!o;

subset Int_0_to_2 of Int where * == 0|1|2;
subset Int_0_or_1 of Int where * == 0|1;

has Int_0_or_1 $.color           = 0;
has Int_0_or_1 $.hide-cursor     = 1;
has Int_0_or_1 $.index           = 0;
has Int_0_or_1 $.loop            = 0;
has Int_0_or_1 $.mouse           = 0;
has Int_0_or_1 $.order           = 1;
has Int_0_or_1 $.show-hidden     = 1;
has Int_0_or_1 $.small-first     = 0;
has Int_0_or_1 $.keep-chosen     = 0;
has Int_0_or_1 $.all-by-default  = 0;   # documentation
has Int_0_to_2 $.alignment       = 0;
has Int_0_to_2 $.clear-screen    = 0;
has Int_0_to_2 $.enchanted       = 1;
has Int_0_to_2 $.layout          = 1;
has List       $.mark            = [];
has Str $.add-dir                     = 'ADD-DIR';
has Str $.back                        = 'BACK';
has Str $.choose-file                 = 'SHOW-FILES';
has Str $.confirm                     = 'CONFIRM';
has Str $.current-selection-begin     = '';
has Str $.current-selection-label;
has Str $.current-selection-end       = '';
has Str $.current-selection-separator = ', ';
has Str $.info                        = '';
has Str $.init-dir                    = $*HOME.Str;
has Str $.parent-dir                  = 'PARENT-DIR';
has Str $.prefix;
has Str $.prompt                      = '';
has Str $.thousands-separator         = ',';

#### old names warnings ###
method !_old_names_warnings ( %opt ) {
    my %map_old_to_new = :up( 'parent-dir' ), :justify( 'alignment' ), :dir( 'init-dir' ), :sofar-begin( 'current-selection-begin' ),
                         :sofar-end( 'current-selection-end' ), :sofar-separator( 'current-selection-separator' ),
                         :name( 'current-selection-label' ), :thsd-sep( 'thousands-separator' );
    my @lines;
    for %opt.keys -> $key {
        if $key eq <justify dir up sofar-begin sofar-end sofar-separator name thsd-sep>.any {
            @lines.push: sprintf "\"%s\"  is now called  \"%s\"", $key, %map_old_to_new{$key};
        }
    }
    if ( @lines ) {
        my $tc = Term::Choose.new();
        $tc.pause( ( 'Close with Enter', ), :prompt( @lines.join: "\n" ), :2layout );
    }
}
##########################

has Term::Choose $!tc;


method !_init_term {
    # :1loop disables hide-cursor in Term::Choose
    $!tc = Term::Choose.new( :mouse( %!o<mouse> ), :1loop, :clear-screen( %!o<clear-screen> ) ); 
    if %!o<hide-cursor> {
        print hide-cursor;
    }
    if %!o<clear-screen> == 2 {
        print save-screen;
    }
    if %!o<clear-screen> {
        print clear;
    }
    else {
        print clr-lines-to-bot;
    }
}

method !_end_term {
    if %!o<clear-screen> == 2 {
        print restore-screen;
    }
    else {
        if ! $!loop {
            print clr-lines-to-bot;
        }
    }
    if %!o<hide-cursor> && ! $!loop {
        print show-cursor;
    }
}


sub _string_gist ( $_ ) { S:g/' '/\ / } # ?


sub choose-dirs ( *%opt ) is export( :DEFAULT, :choose-dirs ) { Term::Choose::Util.new().choose-directories( |%opt ) }  # DEPRECATED    1.3.0
method choose-dirs ( *%opt ) { Term::Choose::Util.new().choose-directories( |%opt ) }                                   # DEPRECATED    1.3.0

sub choose-directories ( *%opt ) is export( :DEFAULT, :choose-directories ) { Term::Choose::Util.new().choose-directories( |%opt ) }

method choose-directories (
        Int_0_or_1 :$color                   = $!color,
        Int_0_or_1 :$mouse                   = $!mouse,
        Int_0_or_1 :$order                   = $!order,
        Int_0_or_1 :$hide-cursor             = $!hide-cursor,
        Int_0_or_1 :$show-hidden             = $!show-hidden,
        Int_0_or_1 :$enchanted               = $!enchanted,
        Int_0_to_2 :$clear-screen            = $!clear-screen,
        Int_0_to_2 :$alignment               = $!alignment,
        Int_0_to_2 :$layout                  = $!layout,
        Str        :$init-dir                = $!init-dir,
        Str        :$info                    = $!info,
        Str        :$current-selection-label = $!current-selection-label // 'Dirs: ', #/
        Str        :$prompt                  = $!prompt,
        Str        :$back                    = $!back,
        Str        :$confirm                 = $!confirm,
        Str        :$add-dir                 = $!add-dir,
        Str        :$parent-dir              = $!parent-dir,
        *%rest                                                      # old names warnings ###
    ) {
    %!o = :$clear-screen, :$mouse, :$hide-cursor;
    self!_old_names_warnings( %rest );                              # old names warnings ###
    self!_init_term();
    my @chosen_dirs;
    my IO::Path $tmp_dir = $init-dir.IO;
    my IO::Path $previous = $tmp_dir;
    my @pre = ( Any, $confirm, $add-dir, $parent-dir );
    my Int $default = $enchanted ?? @pre.end !! 0;

    loop {
        my IO::Path @dirs;
        try {
            if $show-hidden {
                @dirs = $tmp_dir.dir.grep({ .d }).sort;
            }
            else {
                @dirs = $tmp_dir.dir.grep({ .d && .basename !~~ / ^ \. / }).sort;
            }
            CATCH { #
                my $prompt = $tmp_dir.gist ~ ":\n" ~ $_;
                $!tc.pause( [ 'Press ENTER to continue.' ], :$prompt );
                if $tmp_dir.absolute eq '/' {
                    self!_end_term();
                    return Empty;
                }
                $tmp_dir = $tmp_dir.dirname.IO;
                next;
            }
        }
        my @tmp;
        @tmp.push: $info if $info.chars;
        @tmp.push: $current-selection-label ~ @chosen_dirs.map({ _string_gist( $_ ) }).join( ', ' ) ~ "    <<-add-dir-[ $previous ]";
        @tmp.push: $prompt if $prompt.chars;
        my $current_selection = @tmp.join: "\n";
        my @choices = |@pre, |@dirs.map({ .basename });
        # Choose
        my $idx = $!tc.choose(
            @choices,
            :prompt( $current_selection ), :$default, :undef( $back ), :$alignment, :$layout, :$order, :1index,
            :lf( 0, $current-selection-label.chars ), :$color
        );
        if ! $idx[0] {
            if @chosen_dirs.elems {
                @chosen_dirs.pop;
                next;
            }
            self!_end_term();
            return Empty;
        }
        $default = $enchanted ?? @pre.end !! 0;
        if @choices[$idx] eq $confirm {
            self!_end_term();
            return @chosen_dirs;
        }
        elsif @choices[$idx] eq $add-dir {
            @chosen_dirs.push: $previous;
            $tmp_dir = $tmp_dir.dirname.IO;
            $default = 0 if $previous eq $tmp_dir;
            $previous = $tmp_dir;
            next;
        }
        elsif @choices[$idx] eq $parent-dir {
            $tmp_dir = $tmp_dir.dirname.IO;
        }
        else {
            $tmp_dir = @dirs[$idx-@pre];
        }
        $default = 0 if $previous eq $tmp_dir;
        $previous = $tmp_dir;
    }
}


sub choose-a-dir ( *%opt ) is export( :DEFAULT, :choose-a-dir ) { Term::Choose::Util.new().choose-a-dir( |%opt ) } # DEPRECATED 1.3.0
method choose-a-dir ( *%opt ) { Term::Choose::Util.new().choose-a-directory( |%opt ) }                             # DEPRECATED 1.3.0

sub choose-a-directory ( *%opt ) is export( :DEFAULT, :choose-a-directory ) { Term::Choose::Util.new().choose-a-directory( |%opt ) } #  --> IO::Path

method choose-a-directory (
        Int_0_or_1 :$color                   = $!color,
        Int_0_or_1 :$mouse                   = $!mouse,
        Int_0_or_1 :$order                   = $!order,
        Int_0_or_1 :$hide-cursor             = $!hide-cursor,
        Int_0_or_1 :$show-hidden             = $!show-hidden,
        Int_0_or_1 :$enchanted               = $!enchanted,
        Int_0_to_2 :$clear-screen            = $!clear-screen,
        Int_0_to_2 :$alignment               = $!alignment,
        Int_0_to_2 :$layout                  = $!layout,
        Str        :$init-dir                = $!init-dir,
        Str        :$info                    = $!info,
        Str        :$prompt                  = $!prompt,
        Str        :$current-selection-label = $!current-selection-label // 'Dir: ', #/
        Str        :$back                    = $!back,
        Str        :$confirm                 = $!confirm,
        Str        :$parent-dir              = $!parent-dir,
        *%rest                                                      # old names warnings ###
    ) { # --> IO::Path 
    %!o = :$mouse, :$order, :$show-hidden, :$enchanted, :$alignment, :$layout, :$hide-cursor,
          :$init-dir, :$info, :$prompt, :$current-selection-label, :$back, :$confirm, :$parent-dir, :$clear-screen, :$color;
    self!_old_names_warnings( %rest );                              # old names warnings ###
    self!_init_term();
    my $chosen = self!_choose_a_path( 0 );
    self!_end_term();
    return $chosen;
}


sub choose-a-file    ( *%opt ) is export( :DEFAULT, :choose-a-file ) { Term::Choose::Util.new().choose-a-file( |%opt ) } #  --> IO::Path

method choose-a-file (
        Int_0_or_1 :$color                   = $!color,
        Int_0_or_1 :$mouse                   = $!mouse,
        Int_0_or_1 :$order                   = $!order,
        Int_0_or_1 :$hide-cursor             = $!hide-cursor,
        Int_0_or_1 :$show-hidden             = $!show-hidden,
        Int_0_or_1 :$enchanted               = $!enchanted,
        Int_0_to_2 :$clear-screen            = $!clear-screen,
        Int_0_to_2 :$alignment               = $!alignment,
        Int_0_to_2 :$layout                  = $!layout,
        Str        :$init-dir                = $!init-dir,
        Str        :$info                    = $!info,
        Str        :$prompt                  = $!prompt,
        Str        :$current-selection-label = $!current-selection-label // 'File: ',  #/  # New file
        Str        :$back                    = $!back,
        Str        :$confirm                 = $!confirm,
        Str        :$parent-dir              = $!parent-dir,
        Str        :$choose-file             = $!choose-file,
        *%rest                                                      # old names warnings ###
    ) { # --> IO::Path
    %!o = :$mouse, :$order, :$show-hidden, :$enchanted, :$alignment, :$layout, :$init-dir, :$hide-cursor,
          :$info, :$prompt, :$current-selection-label, :$back, :$confirm, :$parent-dir, :$choose-file, :$clear-screen, :$color;
    self!_old_names_warnings( %rest );                              # old names warnings ###
    self!_init_term();
    my $chosen = self!_choose_a_path( 1 );
    self!_end_term();
    return $chosen;
}


method !_choose_a_path ( Int $is_a_file ) { #  --> IO::Path
    my $wildcard = ' ? ';
    my @pre = ( Any, $is_a_file ?? %!o<choose-file> !! %!o<confirm>, %!o<parent-dir> );
    my Int $default = %!o<enchanted>  ?? 2 !! 0;
    my IO::Path $init-dir = %!o<init-dir>.IO;
    my IO::Path $previous = $init-dir;

    loop {
        my IO::Path @dirs;
        try {
            if %!o<show-hidden> {
                @dirs = $init-dir.dir.grep({ .d }).sort;
            }
            else {
                @dirs = $init-dir.dir.grep({ .d && .basename !~~ / ^ \. / }).sort;
            }
            CATCH { #
                my $prompt = $init-dir.gist ~ ":\n" ~ $_;
                $!tc.pause( [ 'Press ENTER to continue.' ], :$prompt );
                if $init-dir.Str eq '/' {
                    return Empty;
                }
                $init-dir = $init-dir.dirname.IO;
                next;
            }
        }
        my @tmp;
        if %!o<info>.chars {
            @tmp.push: %!o<info>;
        }
        if $is_a_file {
            @tmp.push: %!o<current-selection-label> ~ _string_gist( $previous.add: $wildcard );
        }
        else {
            @tmp.push: %!o<current-selection-label> ~ _string_gist( $previous );
        }
        if %!o<prompt>.chars {
            @tmp.push: %!o<prompt>;
        }
        my $choices = [ |@pre, |@dirs.map( { .basename } ) ];
        # Choose
        my $idx = $!tc.choose(
            $choices,
            :$default, :undef( %!o<back> ), :prompt( @tmp.join: "\n" ), :1index, :alignment( %!o<alignment> ),
            :layout( %!o<layout> ), :order( %!o<order> ), :color( %!o<color> )
        );
        if ! $idx.defined || ! $choices[$idx].defined {
            return; # IO::Path;
        }
        if $choices[$idx] eq %!o<confirm> {
            return $previous;
        }
        elsif %!o<choose-file>.defined && $choices[$idx] eq %!o<choose-file> {
            my IO::Path $file = self!_a_file( $init-dir, $wildcard ) // IO::Path;
            next if ! $file.defined;
            return $file;
        }
        if $choices[$idx] eq %!o<parent-dir> {
            $init-dir = $init-dir.dirname.IO;
        }
        else {
            $init-dir = @dirs[$idx-@pre];
        }
        if ( $previous eq $init-dir ) {
            $default = 0;
        }
        else {
            $default = %!o<enchanted>  ?? 2 !! 0;
        }
        $previous = $init-dir;
    }
}


method !_a_file ( IO::Path $init-dir, $wildcard ) { #  --> IO::Path
    my Str $previous;
    my $chosen_file;

    loop {
        my Str @files;
        try {
            if %!o<show-hidden> {
                @files = $init-dir.dir.grep( { .f } ).map: { .basename };
            }
            else {
                @files = $init-dir.dir.grep( { .f } ).map( { .basename } ).grep: { ! / ^ \. / };
            }
            CATCH { #
                my $prompt = $init-dir.gist ~ ":\n" ~ $_;
                $!tc.pause( [ 'Press ENTER to continue.' ], :$prompt );
                return;
            }
        }
        if ! @files.elems {
            my $prompt =  "Dir: $init-dir\nNo files in this directory.";
            $!tc.pause( [ %!o<back> ], prompt => $prompt );
            return;
        }
        my @pre = ( Any );
        if $chosen_file {
            @pre.push: %!o<confirm>;
        }
        my @tmp;
        @tmp.push: %!o<info> if %!o<info>.chars;
        @tmp.push: %!o<current-selection-label> ~ _string_gist( $init-dir.add( $previous // $wildcard ) ); # New file
        @tmp.push: %!o<prompt> if %!o<prompt>.chars;
        # Choose
        $chosen_file = $!tc.choose(
            [ |@pre, |@files.sort ],
            :prompt( @tmp.join: "\n" ), :undef( %!o<back> ), :alignment( %!o<alignment> ),
            :layout( %!o<layout> ), :order( %!o<order> ), :color( %!o<color> )
        );
        if ! $chosen_file.defined {
            return;
        }
        elsif $chosen_file eq %!o<confirm> {
            return if ! $previous.defined;
            return $init-dir.IO.add: $previous;
        }
        else {
            $previous = $chosen_file;
        }
    }
}


sub choose-a-number ( Int $digits = 7, *%opt ) is export( :DEFAULT, :choose-a-number ) {
    Term::Choose::Util.new().choose-a-number( $digits, |%opt );
}

method choose-a-number ( Int $digits = 7,
        Int_0_or_1 :$color                   = $!color,
        Int_0_or_1 :$mouse                   = $!mouse,
        Int_0_or_1 :$small-first             = $!small-first,
        Int_0_or_1 :$hide-cursor             = $!hide-cursor,
        Int_0_to_2 :$clear-screen            = $!clear-screen,
        Str        :$info                    = $!info,
        Str        :$prompt                  = $!prompt,
        Str        :$current-selection-label = $!current-selection-label // '> ', #/
        Str        :$thousands-separator     = $!thousands-separator,
        Str        :$back                    = $!back,
        Str        :$confirm                 = $!confirm,
        *%rest                                                      # old names warnings ###
    ) {
    %!o = :$clear-screen, :$mouse, :$hide-cursor;
    self!_old_names_warnings( %rest );                              # old names warnings ###
    self!_init_term();
    my Int $sep_w;
    if $color {
        my $tmp_sep = $thousands-separator.subst( / \e \[ [ \d \; ]* m /, '', :g );
        $sep_w = print-columns( $tmp_sep );
    }
    else {
        $sep_w = print-columns( $thousands-separator );
    }
    my Int $longest = $digits + ( ( $digits - 1 ) div 3 ) * $sep_w;
    my Str $tab     = '  -  ';
    my Int $tab_w = print-columns( $tab );
    my Str @ranges;
    my ( $back_w, $confirm_w );
    if $color {
        my $tmp_back    =    $back.subst( / \e \[ [ \d \; ]* m /, '', :g );
        my $tmp_confirm = $confirm.subst( / \e \[ [ \d \; ]* m /, '', :g );
        $back_w    = print-columns( $tmp_back    );
        $confirm_w = print-columns( $tmp_confirm );
    }
    else {
        $back_w    = print-columns( $back    );
        $confirm_w = print-columns( $confirm );
    }
    my ( $tmp_back, $tmp_confirm );
    if $longest * 2 + $tab_w <= get-term-width() {
        @ranges = ( sprintf " %*s%s%*s", $longest, '0', $tab, $longest, '9' );
        for 1 .. $digits - 1 -> $zeros { #
            my Str $begin = insert-sep( '1' ~ '0' x $zeros, $thousands-separator );
            my Str $end   = insert-sep( '9' ~ '0' x $zeros, $thousands-separator );
            @ranges.unshift( sprintf " %*s%s%*s", $longest, $begin, $tab, $longest, $end );
        }
        $tmp_back    = $back    ~ ' ' x ( $longest * 2 + $tab_w + 1 - $back_w );
        $tmp_confirm = $confirm ~ ' ' x ( $longest * 2 + $tab_w + 1 - $confirm_w );
    }
    else {
        @ranges = ( sprintf "%*s", $longest, '0' ); #
        for 1 .. $digits - 1 -> $zeros { #
            my Str $begin = insert-sep( '1' ~ '0' x $zeros, $thousands-separator );
            @ranges.unshift( sprintf "%*s", $longest, $begin );
        }
        $tmp_back    = $back    ~ ' ' x ( $longest + 1 - $back_w );
        $tmp_confirm = $confirm ~ ' ' x ( $longest + 1 - $confirm_w );
    }
    my @pre = ( Any, $tmp_confirm );
    my Int %numbers;
    my Str $result;

    NUMBER: loop {
        my Str $new_number = $result // '';
        my @tmp;
        if $info.chars {
            @tmp.push: $info;
        }
        my $row = sprintf(  "{$current-selection-label}%*s", $longest, $new_number );
        if print-columns( $row ) > get-term-width() {
            $row = $new_number;
        }
        @tmp.push: $row;
        if $prompt.chars {
            @tmp.push: $prompt;
        }
        # Choose
        my $range = $!tc.choose(
            [ |@pre, |( $small-first ?? @ranges.reverse !! @ranges ) ],
            :prompt( @tmp.join: "\n" ), :2layout, :1alignment, :undef( $tmp_back ), :$color
        );
        if ! $range.defined {
            if $result.defined {
                $result = Str;
                %numbers = ();
                next NUMBER;
            }
            else {
                self!_end_term();
                return;
            }
        }
        elsif $range eq $tmp_confirm {
            self!_end_term();
            if ! $result.defined {
                return;
            }
            $result.=subst( / $thousands-separator /, '', :g ) if $thousands-separator ne '';
            return $result.Int;
        }
        my Str $begin = ( $range.split( / \s+ '-' \s+ / ) )[0];
        my Int $zeros;
        if $thousands-separator.chars {
            $zeros = $begin.trim-leading.subst( / $thousands-separator /, '', :g ).chars - 1;
        }
        else {
            $zeros = $begin.trim-leading.chars - 1;
        }
        my @choices   = $zeros ?? ( 1 .. 9 ).map( { $_ ~ '0' x $zeros } ) !! 0 .. 9;
        my Str $reset = 'reset';
        my Str $back_short = '<<';
        # Choose
        my $num = $!tc.choose( 
            [ Any, |@choices, $reset ],
            :prompt( @tmp.join: "\n" ), :1layout, :2alignment, :0order, :undef( $back_short ), :$color
        );
        if ! $num.defined {
            next;
        }
        elsif $num eq $reset {
            %numbers{$zeros}:delete;
        }
        else {
            if $thousands-separator ne '' {
                $num.=subst( / $thousands-separator /, '', :g );
            }
            %numbers{$zeros} = $num.Int;
        }
        my Int $num_combined = [+] %numbers.values;
        $result = insert-sep( $num_combined, $thousands-separator ).Str;
    }
}


sub choose-a-subset ( @list, *%opt ) is export( :DEFAULT, :choose-a-subset ) {
    Term::Choose::Util.new().choose-a-subset( @list, |%opt );
}

method choose-a-subset ( @list,
        Int_0_or_1 :$color                       = $!color,
        Int_0_or_1 :$index                       = $!index,
        Int_0_or_1 :$mouse                       = $!mouse,
        Int_0_or_1 :$order                       = $!order,
        Int_0_or_1 :$hide-cursor                 = $!hide-cursor,
        Int_0_or_1 :$keep-chosen                 = $!keep-chosen,
        Int_0_or_1 :$all-by-default              = $!all-by-default,
        Int_0_to_2 :$clear-screen                = $!clear-screen,
        Int_0_to_2 :$alignment                   = $!alignment,
        Int_0_to_2 :$layout                      = 2,
        List       :$mark                        = $!mark,
        Str        :$prefix                      = $!prefix,
        Str        :$info                        = $!info,
        Str        :$prompt                      = 'Choose:',
        Str        :$current-selection-label     = $!current-selection-label // '', #/
        Str        :$current-selection-begin     = $!current-selection-begin;
        Str        :$current-selection-separator = $!current-selection-separator;
        Str        :$current-selection-end       = $!current-selection-end;
        Str        :$back                        = $!back,
        Str        :$confirm                     = $!confirm,
        *%rest                                                      # old names warnings ###

    ) {
    %!o = :$clear-screen, :$mouse, :$hide-cursor;
    self!_old_names_warnings( %rest );                              # old names warnings ###
    self!_init_term();
    my Str $tmp_prefix  = $prefix // ( $layout == 2 ?? '- ' !! '' );
    my Str $tmp_confirm = $confirm;
    my Str $tmp_back    = $back;
    if $layout == 2 && $tmp_prefix.chars {
        $tmp_confirm = ( ' ' x $tmp_prefix.chars ) ~ $tmp_confirm;
        $tmp_back    = ( ' ' x $tmp_prefix.chars ) ~ $tmp_back;
    }
    my List $new_idx = [];
    my List $new_val = [ @list ];
    my @pre = ( Any, $tmp_confirm );
    my List $initially_marked = [ |$mark.map: { $_ + @pre.elems } ];
    my @bu;

    loop {
        my @tmp;
        if $info.chars {
             @tmp.push: $info;
        }
        my $sofar;
        if $current-selection-label.defined {
            $sofar ~= $current-selection-label;
        }
        if $new_idx.elems {
            $sofar ~= $current-selection-begin ~ @list[|$new_idx].map( { $_ // '' } ).join( $current-selection-separator ) ~ $current-selection-end;
        }
        elsif $all-by-default {
            $sofar ~= $current-selection-begin ~ '*' ~ $current-selection-end;
        }
        if $sofar.defined {  # test ### 
            @tmp.push: $sofar;
        }
        if $prompt.chars {
            @tmp.push: $prompt;
        }
        my $choices = [ |@pre, |$new_val.map: { $tmp_prefix ~ $_.gist } ];
        # Choose
        my Int @idx = $!tc.choose-multi(
            $choices,
            :prompt( @tmp.join: "\n" ), :meta-items( |^@pre ), :undef( $tmp_back ), :lf( 0, $current-selection-label.chars ),
            :$alignment, :1index, :$layout, :$order, :mark( $initially_marked ), :2include-highlighted, :$color
        );
        if $initially_marked.defined {
            $initially_marked = List;
        }
        if ! @idx[0].defined || @idx[0] == 0 {
            if @bu {
                ( $new_val, $new_idx ) = @bu.pop;
                next;
            }
            self!_end_term();
            return;
        }
        @bu.push( [ [ |$new_val ], [ |$new_idx ] ] );
        my $ok;
        if @idx[0] == @pre.first( $tmp_confirm, :k ) {
            $ok = True;
            @idx.shift;
        }
        my @tmp_idx;
        for @idx.reverse {
            my $i = $_ - @pre;
            if ! $keep-chosen {
                $new_val.splice( $i, 1 );
                for $new_idx.sort -> $u {
                    last if $u > $i;
                    ++$i;
                }
            }
            @tmp_idx.push: $i;
        }
        $new_idx.append: @tmp_idx.reverse;
        if $ok {
            if ! $new_idx.elems && $all-by-default {
                $new_idx = [ 0 .. @list.end ];
            }
            self!_end_term();
            return $index ?? $new_idx !! [ @list[|$new_idx] ];
        }
    }
}


sub settings-menu ( @menu, %setup, *%opt ) is export( :DEFAULT, :settings-menu ) {
    Term::Choose::Util.new().settings-menu( @menu, %setup, |%opt );
}

method settings-menu ( @menu, %setup,
        Int_0_or_1 :$color                   = $!color,
        Int_0_or_1 :$mouse                   = $!mouse,
        Int_0_or_1 :$hide-cursor             = $!hide-cursor,
        Int_0_to_2 :$clear-screen            = $!clear-screen,
        Str        :$info                    = $!info,
        Str        :$prompt                  = 'Choose:',
        Str        :$back                    = $!back,
        Str        :$confirm                 = $!confirm,
        Str        :$current-selection-label = $!current-selection-label,
        *%rest                                                      # old names warnings ###
    ) {
    %!o = :$clear-screen, :$mouse, :$hide-cursor;
    self!_old_names_warnings( %rest );                              # old names warnings ###
    self!_init_term();
    my Int $longest = 0;
    my %name_w;
    my %new_setup;
    for @menu -> ( Str $key, Str $name, $ ) {
        if $color {
            my $tmp_name = $name.subst( / \e \[ [ \d \; ]* m /, '', :g );
            %name_w{$key} = print-columns( $tmp_name );
        }
        else {
            %name_w{$key} = print-columns( $name );
        }
        $longest max= %name_w{$key};
        %setup{$key} //= 0;
        %new_setup{$key} = %setup{$key};
    }
    my @pre = Any, $confirm;
    my Str @print_keys;
    for @menu -> ( Str $key, Str $name, @values ) {
        my $current = @values[%new_setup{$key}];
        @print_keys.push: $name ~ ( ' '  x ( $longest - %name_w{$key} ) ) ~ " [$current]";
    }
    %*ENV<TC_RESET_AUTO_UP> = 0;
    my Int $default = 0;
    my Int $count = 0;

    loop {
        my @tmp;
        if $current-selection-label.defined {
            @tmp.push: $current-selection-label ~ %new_setup.keys.map({ "$_=%new_setup{$_}" }).join: ', ';
        }
        if $prompt.defined && $prompt.chars {
            @tmp.push: $prompt;
        }
        my $comb_prompt = @tmp.join: "\n";
        # Choose
        my Int $idx = $!tc.choose(
            [ |@pre, |@print_keys ],
            :$info, :prompt( $comb_prompt ), :1index, :$default, :2layout, :0alignment, :undef( $back ), :$color
        );
        if ! $idx {
            self!_end_term();
            return False; ###
        }
        elsif $idx == @pre.end {
            my Int $change = 0;
            for @menu -> ( Str $key, $, $ ) {
                if %setup{$key} == %new_setup{$key} {
                    next;
                }
                %setup{$key} = %new_setup{$key};
                $change++;
            }
            self!_end_term();
            return $change.so; ###
        }
        my \i = $idx-@pre.elems;
        if $default == $idx {
            if %*ENV<TC_RESET_AUTO_UP> {
                $count = 0;
            }
            elsif $count == @menu[i][2].elems {
                $default = 0;
                $count = 0;
                next;
            }
        }
        else {
            $count = 0;
            $default = $idx;
        }
        ++$count;
        my \key = @menu[i][0];
        ++%new_setup{key};
        if %new_setup{key} > @menu[i][2].end {
            %new_setup{key} = 0;
        }
        @print_keys[i] ~~ s/ '[' <-[\[\]]>+ ']' $ /[@menu[i][2][%new_setup{key}]]/;
    }
}


sub insert-sep ( $num, $thousands-separator = ' ' ) is export( :insert-sep ) {
    return $num if ! $num.defined;
    return $num if $num ~~ /$thousands-separator/;
    my token sign { <[+-]> }
    my token int  { \d+ }
    my token rest { \D \d+ }
    if $num !~~ / ^ <sign>? <int> <rest>? $ / {
        return $num;
    }
    #while $num.=subst( / ^ ( -? \d+ ) ( \d\d\d ) /, "$0$thousands-separator$1" ) {};
    my $new = $<sign> // '';
    $new   ~= $<int>.flip.comb( / . ** 1..3 / ).join( $thousands-separator ).flip;
    $new   ~= $<rest> // '';
    return $new;
}

#sub unicode-sprintf ( Str $str, Int $avail_col_w, @cache? :$alignment, :$add_dots ) is export( :unicode-sprintf ) { #
sub unicode-sprintf ( Str $str, Int $avail_col_w, Int $alignment, @cache? ) is export( :unicode-sprintf ) {
    my Int $str_length = print-columns( $str );
    if $str_length > $avail_col_w {
        #if $add_dots {
        #   return to-printwidth( $str, $avail_col_w - 3 ) ~ '...';
        #}
        return to-printwidth( $str, $avail_col_w, False, @cache ).[0];
    }
    elsif $str_length < $avail_col_w {
        if $alignment == 0 {
            return $str ~ " " x ( $avail_col_w - $str_length );
        }
        elsif $alignment == 1 {
            return " " x ( $avail_col_w - $str_length ) ~ $str;
        }
        elsif $alignment == 2 {
            my Int $all = $avail_col_w - $str_length;
            my Int $half = $all div 2;
            return " " x $half ~ $str ~ " " x ( $all - $half );
        }
    }
    else {
        return $str;
    }
}



=begin pod

=head1 NAME

Term::Choose::Util - TUI-related functions for selecting directories, files, numbers and subsets of lists.

=head1 DESCRIPTION

This module provides TUI-related functions for selecting directories, files, numbers and subsets of lists.

=head1 CONSTRUCTOR

The constructor method C<new> can be called with optional named arguments:

=begin code

    my $new = Term::Choose::Util.new( :mouse(1), ... )

=end code

=head2 DEPRECATIONS

The use of C<choose-dirs> is deprecated - use C<choose-directories> instead.

The use of C<choose-a-dir> is deprecated - use C<choose-a-directory> instead.

The deprecated routine names will be removed.

=head2 RENAMED OPTIONS

    <Old names>:        <New names>:

    justify             alignment

    dir                 init-dir

    up                  parent-dir

    name                current-selection-label

    sofar-begin         current-selection-begin

    sofar-separator     current-selection-separator

    sofar-end           current-selection-end

    thsd-sep            thousands-separator

Only the new option names work.

=head1 ROUTINES

Values in brackets are default values.

=head3 Options available for all subroutines

=item1 clear-screen

If enabled, the screen is cleared before the output.

Values: [0],1.

=item1 color

Enables the support for color and text formatting escape sequences.

Values: [0],1.

=item1 hide-cursor

Hide the cursor

Values: 0,[1].

=item1 info

A string placed on top of of the output.

Default: undef

=item1 mouse

Enable the mouse mode. An item can be chosen with the left mouse key, the right mouse key can be used instead of the
SpaceBar key.

Values: [0],1.

=item1 current-selection-label

The value of I<current-selection-label> is a string which is placed in front of the "chosen so far" info output.

With C<settings-menu> the "chosen so far" info output is only shown if I<current-selection-label> is defined.

Defaults: C<choose-directories>: 'Dirs: ', C<choose-a-directory>: 'Dir: ', C<choose-a-file>: 'File: ',
C<choose-a-number>: ' >', C<choose-a-subset>: '', C<settings-menu>: undef

The "chosen so far" info output is placed between the I<info> string and the I<prompt> string.

=item1 prompt

A string placed on top of the available choices.

Default: undef

=item1 back

Customize the string of the menu entry "back".

Default: C<BACK>

=item1 confirm

Customize the string of the menu entry "confirm".

Default: C<CONFIRM>.

=head2 choose-a-directory

=begin code

    $chosen-directory = choose-a-directory( :layout(1), ... )

=end code

With C<choose-a-directory> the user can browse through the directory tree and choose a directory which is returned.

To move around in the directory tree:

- select a directory and press C<Return> to enter in the selected directory.

- choose the "parent-dir" menu entry to move upwards.

To return the current working-directory as the chosen directory choose the "confirm" menu entry.

The "back" menu entry causes C<choose-a-directory> to return nothing.

Following options can be set:

=item1 alignment

Elements in columns are aligned to the left if set to 0, aligned to the right if set to 1 and centered if set to 2.

Values: [0],1,2.

=item1 init-dir

Set the starting point directory. Defaults to the home directory (C<$*HOME>).

=item1 enchanted

If set to 1, the default cursor position is on the "parent-dir" menu entry. If the directory name remains the same after an user
input, the default cursor position changes to "back".

If set to 0, the default cursor position is on the "back" menu entry.

Values: 0,[1].

=item1 layout

See the option I<layout> in L<Term::Choose|https://github.com/kuerbis/Term-Choose-p6>

Values: 0,[1],2.

=item1 order

If set to 1, the items are ordered vertically else they are ordered horizontally.

This option has no meaning if I<layout> is set to 2.

Values: 0,[1].

=item1 show-hidden

If enabled, hidden directories are added to the available directories.

Values: 0,[1].

=item1 parent-dir

Customize the string of the menu entry "parent-dir".

Default: PARENT-DIR

=item1 L<#Options available for all subroutines>

=head2 choose-a-file

=begin code

    $chosen-file = choose-a-file( :layout(1), ... )

=end code

Browse the directory tree the same way as described for C<choose-a-directory>. Select the "show-files" menu entry to get
the files of the current directory. To return the chosen file select the "confirm" menu entry.

Options as in L<#choose-a-directory> plus

=item1 show-files

Customize the string of the menu entry "show-files".

Default: C<SHOW-FILES>

=head2 choose-directories

=begin code

    @chosen-directories = choose-directories( :layout(1), ... )

=end code

C<choose-directories> is similar to C<choose-a-directory> but it is possible to return multiple directories.

Use the "add-dir" menu entry to add the current directory to the list of chosen directories.

To return the list of chosen directories select the "confirm" menu entry.

The "back" menu entry removes the last added directory. If the list of chosen directories is empty, "back" causes
choose-directories to return nothing.

Options as in L<#choose-a-directory> plus

=item1 add-dir

Customize the string of the menu entry "add-dir".

Default: C<ADD-DIR>

=head2 choose-a-number

=begin code

    my $number = choose-a-number( 5, :name<Testnumber>, ... );

=end code

This function lets you choose/compose a number (unsigned integer) which is then returned.

The fist argument is an integer and determines the range of the available numbers. For example setting the
first argument to C<4> would offer a range from C<0> to C<9999>. If not set, it defaults to C<7>.

Options:

=item1 small-first

Put the small number ranges on top.

=item1 thousands-separator

Sets the thousands separator.

Default: C<,>

=item1 L<#Options available for all subroutines>

=head2 choose-a-subset

=begin code

    $subset = choose-a-subset( @available-items, :layout( 1 ), ... )

=end code

C<choose-a-subset> lets you choose a subset from a list.

The subset is returned as an array.

The first argument is the list of choices.

Options:

=item1 alignment

Elements in columns are aligned to the left if set to 0, aligned to the right if set to 1 and centered if set to 2.

Values: [0],1,2.

=item1 index

If true, the index positions in the available list of the made choices are returned.

Values: [0],1.

=item1 keep-chosen

If enabled, the chosen items are not removed from the available choices.

Values: [0],1;

=item1 layout

See the option I<layout> in L<Term::Choose>.

Values: 0,1,2,[3].

=item1 mark

Expects as its value a reference to an array with indexes. Elements corresponding to these indexes are pre-selected when
C<choose-a-subset> is called.

=item1 order

If set to 1, the items are ordered vertically else they are ordered horizontally.

This option has no meaning if I<layout> is set to 3.

Values: 0,[1].

=item1 prefix

I<prefix> expects as its value a string. This string is put in front of the elements of the available list in the menu.
The chosen elements are returned without this I<prefix>.

Default: empty string.

=item1 current-selection-begin

Info output: the I<current-selection-begin> string is placed between the I<current-selection-label> string and the
chosen elements as soon as an element has been chosen.

Default: empty string

=item1 current-selection-separator

Info output: I<current-selection-separator> is placed between the chosen list elements.

Default: C< ,>

=item1 current-selection-end

Info output: as soon as elements have been chosen the I<current-selection-end> string is placed at the end of the chosen elements.

Default: empty string

=item1 L<#Options available for all subroutines>

To return the chosen subset select the "confirm" menu entry.

The "back" menu entry removes the last added chosen items. If the list of chosen items is empty, "back" causes
C<choose-a-subset> to return nothing.

=head2 settings-menu

=begin code

    my @menu = (
        ( 'enable-logging', "- Enable logging", ( 'NO', 'YES' )   ),
        ( 'case-sensitive', "- Case sensitive", ( 'NO', 'YES' )   ),
        ( 'attempts',       "- Attempts"      , ( '1', '2', '3' ) )
    );

    my %config = (
        'enable-logging' => 0,
        'case-sensitive' => 1,
        'attempts'       => 2
    );

    settings-menu( @menu, %config, :1mouse, ... );

=end code

The first argument is a list of lists. Each of the lists have three elements:

    the option name

    the prompt string

    a list of the available values for the option

The second argument is a hash:

    the hash key is the option name

    the hash value (zero based index) sets the current value for the option.

This hash is edited in place: the changes made by the user are saved in this hash.

Options: see L<#Options available for all subroutines>.


When C<settings-menu> is called, it displays for each list entry a row with the prompt string and the current value.

It is possible to scroll through the rows. If a row is selected, the set and displayed value changes to the next.After
scrolling through the list once the cursor jumps back to the top row.

If the "back" menu entry is chosen, C<settings-menu> does not apply the made changes and returns nothing. If the
"confirm" menu entry is chosen, C<settings-menu> applies the made changes in place to the passed configuration hash
(second argument) and returns the number of made changes.

Setting the option I<current-selection-label> to a defined value adds an info output line.

=head1 AUTHOR

Matthäus Kiem <cuer2s@gmail.com>

=head1 CREDITS

Thanks to the people from L<Perl-Community.de|http://www.perl-community.de>, from
L<stackoverflow|http://stackoverflow.com> and from L<#perl6 on irc.freenode.net|irc://irc.freenode.net/#perl6> for the
help.

=head1 LICENSE AND COPYRIGHT

Copyright 2016-2019 Matthäus Kiem.

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
