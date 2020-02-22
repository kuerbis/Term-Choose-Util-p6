use v6;
unit class Term::Choose::Util:ver<1.3.3>;

use Term::Choose;
use Term::Choose::LineFold;
use Term::Choose::Screen;

subset Int_0_to_2 of Int where * == 0|1|2;
subset Int_0_or_1 of Int where * == 0|1;

has Int_0_or_1 $.hide-cursor     = 1;
has Int_0_or_1 $.index           = 0;
has Int_0_or_1 $.loop            = 0;
has Int_0_or_1 $.mouse           = 0;
has Int_0_or_1 $.order           = 1;
has Int_0_or_1 $.show-hidden     = 1;
has Int_0_or_1 $.small-first     = 0;
has Int_0_or_1 $.keep-chosen     = 0;
has Int_0_or_1 $.all-by-default  = 0;
has Int_0_to_2 $.alignment       = 0;
has Int_0_to_2 $.clear-screen    = 0;
has Int_0_to_2 $.color           = 0;
has Int_0_to_2 $.enchanted       = 1;
has Int_0_to_2 $.layout          = 1;
has List       $.mark            = [];
has List       $.tabs-info       = [];  # no doc
has List       $.tabs-prompt     = [];  # no doc
has Str $.add-dirs               = '[Add-Dirs]';
has Str $.back                   = 'BACK';
has Str $.show-files             = '[Show-Files]';
has Str $.confirm                = 'CONFIRM';
has Str $.cs-begin               = '';
has Str $.cs-label;
has Str $.cs-end                 = '';
has Str $.cs-separator           = ', ';
has Str $.filter;
has Str $.info                   = '';
has Str $.init-dir               = $*HOME.Str;
has Str $.parent-dir             = 'Parent-DIR';
has Str $.prefix;
has Str $.prompt                 = '';
has Str $.thousands-separator    = ',';
has Str $.reset                  = 'reset'; # no doc


#### old names warnings ###
method !_old_names_warnings ( %opt ) {
    my %map_old_to_new = :up( 'parent-dir' ), :justify( 'alignment' ), :dir( 'init-dir' ), :sofar-begin( 'cs-begin' ),
                         :sofar-end( 'cs-end' ), :sofar-separator( 'cs-separator' ), :name( 'cs-label' ),
                         :thsd-sep( 'thousands-separator' ), :current-selection-begin( 'cs-begin' ),
                         :current-selection-end( 'cs-end' ), :current-selection-separator( 'cs-separator' ),
                         :current-selection-label( 'cs-label' ), :add-dir( 'add-dirs' ), :choose-file( 'show-files' );
    my @lines;
    for %opt.keys -> $key {
        if $key eq %map_old_to_new.keys.any {
            @lines.push: sprintf "\"%s\" is now called \"%s\"", $key, %map_old_to_new{$key};
        }
    }
    if ( @lines ) {
        my $tc = Term::Choose.new();
        $tc.pause( ( 'Close with Enter', ), :prompt( @lines.join: "\n" ), :2layout );
    }
}
##########################

has Term::Choose $!tc;


method !_init_term ( %opt ) {
    # :1loop disables hide-cursor in Term::Choose
    $!tc = Term::Choose.new( :mouse( %opt<mouse> ), :1loop, :clear-screen( %opt<clear-screen> ), :color( %opt<color> ) );
    if %opt<hide-cursor> {
        print hide-cursor;
    }
    if %opt<clear-screen> == 2 {
        print save-screen;
    }
    if %opt<clear-screen> {
        print clear;
    }
    else {
        print clr-lines-to-bot;
    }
}

method !_end_term ( %opt ) {
    if %opt<clear-screen> == 2 {
        print restore-screen;
    }
    else {
        if ! $!loop {
            print clr-lines-to-bot;
        }
    }
    if %opt<hide-cursor> && ! $!loop {
        print show-cursor;
    }
}


sub choose-dirs ( *%opt ) is export( :DEFAULT, :choose-dirs ) { Term::Choose::Util.new().choose-directories( |%opt ) }  # DEPRECATED    1.3.0
method choose-dirs ( *%opt ) { Term::Choose::Util.new().choose-directories( |%opt ) }                                   # DEPRECATED    1.3.0

sub choose-directories ( *%opt ) is export( :DEFAULT, :choose-directories ) { Term::Choose::Util.new().choose-directories( |%opt ) }

method choose-directories (
        Int_0_or_1 :$mouse        = $!mouse,
        Int_0_or_1 :$order        = $!order,
        Int_0_or_1 :$hide-cursor  = $!hide-cursor,
        Int_0_or_1 :$show-hidden  = $!show-hidden,
        Int_0_or_1 :$enchanted    = $!enchanted,
        Int_0_to_2 :$clear-screen = $!clear-screen,
        Int_0_to_2 :$color        = $!color,
        Int_0_to_2 :$alignment    = $!alignment,
        Int_0_to_2 :$layout       = $!layout,
        Str        :$init-dir     = $!init-dir,
        Str        :$info         = $!info,
        Str        :$cs-label     = $!cs-label // 'Dirs: ', #/
        Str        :$prompt       = $!prompt,
        Str        :$back         = $!back,
        Str        :$confirm      = $!confirm,
        Str        :$add-dirs     = $!add-dirs,
        Str        :$parent-dir   = $!parent-dir,
        List       :$tabs-info    = $!tabs-info,
        List       :$tabs-prompt  = $!tabs-prompt,
        *%rest # old names warnings ###
    ) {
    self!_old_names_warnings( %rest ); # old names warnings ###
    my %opt_term = :$clear-screen, :$mouse, :$hide-cursor, :$color;
    self!_init_term( %opt_term );
    my @chosen_dirs; #
    my IO::Path $current_dir = $init-dir.IO;
    my IO::Path $previous = $current_dir;
    my Str ( $browse, $add_dirs ) = ( 'Browse', 'Add_Dirs' );
    my Str $mode = $browse;
    my @bu;

    loop {
        if $mode eq $browse {
            my %opt_path = :$cs-label, :info( '' ), :$order, :$prompt, :$show-hidden, :$enchanted, :$alignment, :$layout,
                           :$tabs-info, :$tabs-prompt, :$init-dir, :$back, :$confirm, :$add-dirs, :$parent-dir, :$color;
            ( $current_dir, my Int $to_add_dirs ) = self!_choose_a_path( 'choose-directories', $current_dir, %opt_path, :@chosen_dirs );
            if ! $current_dir.defined {
                if @bu.elems {
                    ( $current_dir, @chosen_dirs ) = @bu.pop;
                    next;
                }
                self!_end_term( %opt_term );
                return;
            }
            if $to_add_dirs {
                $mode = $add_dirs;
                next;
            }
            else {
                self!_end_term( %opt_term );
                return @chosen_dirs;
            }
        }
        elsif $mode eq $add_dirs {
            my IO::Path @avail_dirs;
            try {
                if $show-hidden {
                    @avail_dirs = $current_dir.dir.grep({ .d }).sort;
                }
                else {
                    @avail_dirs = $current_dir.dir.grep({ .d && .basename !~~ / ^ \. / }).sort;
                }
                CATCH {
                    my $p = $current_dir ~ ":\n" ~ $_;
                    $!tc.pause( [ 'Press ENTER to continue.' ], :$p );
                    $mode = $browse;
                    next;
                }
            }
            my Str $tmp_info = $info // '';
            if $tmp_info.chars {
                $tmp_info ~= "\n";
            }
            my Int $cs_label_w = print-columns-ext( $cs-label, $color );
            $tmp_info ~= line-fold(
                $cs-label ~ @chosen_dirs.join( ', ' ),
                get-term-width(),
                :subseq-tab( ' ' x $cs_label_w ), :$color
            ).join: "\n";
            my Str $prompt = 'Choose directories:' ~ "\n>" ~ $current_dir;
            my $idxs = self.choose-a-subset(
                @avail_dirs.map({ .basename }).sort,
                :back( '<<' ), :confirm( 'OK' ), :$prompt, :cs-begin( '+ ' ), :cs-label( '' ),
                :info( $tmp_info ), :1index, :0layout, :0hide-cursor
            );
            if $idxs.defined && $idxs.elems {
                @bu.push: [ $current_dir, [ |@chosen_dirs ] ];
                @chosen_dirs.push: |@avail_dirs[|$idxs];
            }
            $mode = $browse;
            next;
        }
    }
}


sub choose-a-dir ( *%opt ) is export( :DEFAULT, :choose-a-dir ) { Term::Choose::Util.new().choose-a-dir( |%opt ) } # DEPRECATED 1.3.0
method choose-a-dir ( *%opt ) { Term::Choose::Util.new().choose-a-directory( |%opt ) }                             # DEPRECATED 1.3.0

sub choose-a-directory ( *%opt ) is export( :DEFAULT, :choose-a-directory ) { Term::Choose::Util.new().choose-a-directory( |%opt ) } #  --> IO::Path

method choose-a-directory (
        Int_0_or_1 :$mouse        = $!mouse,
        Int_0_or_1 :$order        = $!order,
        Int_0_or_1 :$hide-cursor  = $!hide-cursor,
        Int_0_or_1 :$show-hidden  = $!show-hidden,
        Int_0_or_1 :$enchanted    = $!enchanted,
        Int_0_to_2 :$clear-screen = $!clear-screen,
        Int_0_to_2 :$color        = $!color,
        Int_0_to_2 :$alignment    = $!alignment,
        Int_0_to_2 :$layout       = $!layout,
        Str        :$init-dir     = $!init-dir,
        Str        :$info         = $!info,
        Str        :$prompt       = $!prompt,
        Str        :$cs-label     = $!cs-label // 'Dir: ', #/
        Str        :$back         = $!back,
        Str        :$confirm      = $!confirm,
        Str        :$parent-dir   = $!parent-dir,
        List       :$tabs-info    = $!tabs-info,
        List       :$tabs-prompt  = $!tabs-prompt,
        *%rest # old names warnings ###
    ) { # --> IO::Path
    self!_old_names_warnings( %rest ); # old names warnings ###
    my %opt_term = :$clear-screen, :$mouse, :$hide-cursor, :$color;
    self!_init_term( %opt_term );
    my IO::Path $current_dir = $init-dir.IO;
    my %opt_path = :$order, :$show-hidden, :$enchanted, :$alignment, :$layout, :$tabs-info, :$tabs-prompt,
                   :$info, :$prompt, :$cs-label, :$back, :$confirm, :$parent-dir;
    my IO::Path $chosen_path = self!_choose_a_path( 'choose-a-directory', $current_dir, %opt_path );
    self!_end_term( %opt_term );
    return $chosen_path;
}


sub choose-a-file    ( *%opt ) is export( :DEFAULT, :choose-a-file ) { Term::Choose::Util.new().choose-a-file( |%opt ) } #  --> IO::Path

method choose-a-file (
        Int_0_or_1 :$mouse        = $!mouse,
        Int_0_or_1 :$order        = $!order,
        Int_0_or_1 :$hide-cursor  = $!hide-cursor,
        Int_0_or_1 :$show-hidden  = $!show-hidden,
        Int_0_or_1 :$enchanted    = $!enchanted,
        Int_0_to_2 :$clear-screen = $!clear-screen,
        Int_0_to_2 :$color        = $!color,
        Int_0_to_2 :$alignment    = $!alignment,
        Int_0_to_2 :$layout       = $!layout,
        Str        :$filter       = $!filter,
        Str        :$init-dir     = $!init-dir,
        Str        :$info         = $!info,
        Str        :$prompt       = $!prompt,
        Str        :$cs-label     = $!cs-label // 'File: ',  #/
        Str        :$back         = $!back,
        Str        :$confirm      = $!confirm,
        Str        :$parent-dir   = $!parent-dir,
        Str        :$show-files   = $!show-files,
        List       :$tabs-info    = $!tabs-info,
        List       :$tabs-prompt  = $!tabs-prompt,
        *%rest # old names warnings ###
    ) { # --> IO::Path
    self!_old_names_warnings( %rest ); # old names warnings ###
    my %opt_term = :$clear-screen, :$mouse, :$hide-cursor, :$color;
    self!_init_term( %opt_term );
    my IO::Path $current_dir = $init-dir.IO;
    my %opt_path = :$order, :$show-hidden, :$enchanted, :$alignment, :$layout, :$filter, :$info, :$prompt,
                   :$cs-label, :$back, :$confirm, :$parent-dir, :$show-files, :$tabs-info, :$tabs-prompt;
    my IO::Path $chosen_file = self!_choose_a_path( 'choose-a-file', $current_dir, %opt_path );
    self!_end_term( %opt_term );
    return $chosen_file;
}


method !_choose_a_path ( Str $caller, IO::Path $current_dir is rw, %opt, :@chosen_dirs ) { #  --> IO::Path
    my @pre;
    my Int $enchanted_idx;
    if $caller eq 'choose-a-directory' {
        @pre = ( Int, %opt<confirm>, %opt<parent-dir> );
        $enchanted_idx = 2;
    }
    elsif $caller eq 'choose-a-file' {
        @pre = ( Int, %opt<show-files>, %opt<parent-dir> );
        $enchanted_idx = 2;
    }
    elsif $caller eq 'choose-directories' {
        @pre = ( Int, %opt<confirm>, %opt<add-dirs>, %opt<parent-dir> );
        $enchanted_idx = 3;
    }
    my Int $default = %opt<enchanted> ?? $enchanted_idx !! 0;
    my IO::Path $previous = $current_dir;
    my Str $wildcard = ' ? ';

    loop {
        my IO::Path @dirs;
        try {
            if %opt<show-hidden> {
                @dirs = $current_dir.dir.grep({ .d }).sort;
            }
            else {
                @dirs = $current_dir.dir.grep({ .d && .basename !~~ / ^ \. / }).sort;
            }
            CATCH {
                my $p = $current_dir.gist ~ ":\n" ~ $_;
                $!tc.pause( [ 'Press ENTER to continue.' ], :$p );
                if $current_dir.Str eq '/' {
                    return Empty;
                }
                $current_dir = $current_dir.dirname.IO;
                next;
            }
        }
        my Str @tmp;
        if $caller eq 'choose-a-file' {
            @tmp.push: %opt<cs-label> ~ $previous.add( $wildcard );
            if %opt<prompt>.defined && %opt<prompt>.chars {
                @tmp.push: %opt<prompt>;
            }
        }
        elsif $caller eq 'choose-directories' {
            my Int $cs_label_w = print-columns-ext( %opt<cs-label>, %opt<color> );
            @tmp.push: line-fold(
                %opt<cs-label> ~ @chosen_dirs.join( ', ' ),
                get-term-width(),
                :subseq-tab( ' ' x $cs_label_w ), :color( %opt<color> )
            ).join: "\n";
            @tmp.push: %opt<prompt>.defined && %opt<prompt>.chars ?? %opt<prompt> !! 'Browse directories:';
            @tmp.push: ">$previous";
        }
        else {
            @tmp.push: %opt<cs-label> ~ $previous;
            if %opt<prompt>.defined && %opt<prompt>.chars {
                @tmp.push: %opt<prompt>;
            }
        }
        my @choices = |@pre, |@dirs.map( { .basename } );
        # Choose
        my Int $idx = $!tc.choose(
            @choices,
            :$default, :undef( %opt<back> ), :info( %opt<info> ), :prompt( @tmp.join: "\n" ), :1index, :alignment( %opt<alignment> ),
            :layout( %opt<layout> ), :order( %opt<order> )
        );
        if ! $idx.defined || ! @choices[$idx].defined {
            return; # IO::Path;
        }
        if @choices[$idx] eq %opt<confirm> {
            return $previous;
        }
        elsif %opt<show-files>.defined && @choices[$idx] eq %opt<show-files> {
            my IO::Path $file = self!_a_file( $current_dir, $wildcard, %opt ) // IO::Path;
            next if ! $file.defined;
            return $file;
        }
        elsif %opt<add-dirs>.defined && @choices[$idx] eq %opt<add-dirs> {
            return $previous, 1;
        }
        if @choices[$idx] eq %opt<parent-dir> {
            $current_dir = $current_dir.dirname.IO;
        }
        else {
            $current_dir = @dirs[$idx-@pre];
        }
        if ( $previous eq $current_dir ) {
            $default = 0;
        }
        else {
            $default = %opt<enchanted> ?? $enchanted_idx !! 0;
        }
        $previous = $current_dir;
    }
}


method !_a_file ( IO::Path $current_dir, $wildcard, %opt ) { #  --> IO::Path
    my Str $previous;
    my Str $chosen_file;

    loop {
        my Str @files;
        try {
            if %opt<filter> {
                my $regex = %opt<filter>;
                @files = $current_dir.dir( :test( / <$regex> / ) ).grep( { .f } ).map: { .basename };
            }
            else {
                @files = $current_dir.dir(                       ).grep( { .f } ).map: { .basename };
            }
            if ! %opt<show-hidden> {
                @files = @files.grep: { ! / ^ \. / };
            }
            CATCH { #
                my $prompt = $current_dir.gist ~ ":\n" ~ $_;
                $!tc.pause( [ 'Press ENTER to continue.' ], :$prompt );
                return;
            }
        }
        if ! @files.elems {
            my $p =  "Dir: $current_dir\nNo files in this directory.";
            $!tc.pause( [ %opt<back> ], prompt => $p );
            return;
        }
        my @pre = ( Str );
        if $chosen_file {
            @pre.push: %opt<confirm>;
        }
        my Str @tmp;
        @tmp.push: %opt<info> if %opt<info>.chars;
        @tmp.push: %opt<cs-label> ~ $current_dir.add( $previous // $wildcard );
        @tmp.push: %opt<prompt> if %opt<prompt>.chars;
        # Choose
        $chosen_file = $!tc.choose(
            [ |@pre, |@files.sort ],
            :prompt( @tmp.join: "\n" ), :undef( %opt<back> ), :alignment( %opt<alignment> ),
            :layout( %opt<layout> ), :order( %opt<order> )
        );
        if ! $chosen_file.defined {
            return;
        }
        elsif $chosen_file eq %opt<confirm> {
            return if ! $previous.defined;
            return $current_dir.add: $previous;
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
        Int_0_or_1 :$mouse               = $!mouse,
        Int_0_or_1 :$small-first         = $!small-first,
        Int_0_or_1 :$hide-cursor         = $!hide-cursor,
        Int_0_to_2 :$clear-screen        = $!clear-screen,
        Int_0_to_2 :$color               = $!color,
        Str        :$info                = $!info,
        Str        :$prompt              = $!prompt,
        Str        :$cs-label            = $!cs-label // '> ', #/
        Str        :$thousands-separator = $!thousands-separator,
        Str        :$back                = $!back,
        Str        :$confirm             = $!confirm,
        Str        :$reset               = $!reset,
        List       :$tabs-info           = $!tabs-info,
        List       :$tabs-prompt         = $!tabs-prompt,
        *%rest # old names warnings ###
    ) {
    self!_old_names_warnings( %rest ); # old names warnings ###
    my %opt_term = :$clear-screen, :$mouse, :$hide-cursor, :$color;
    self!_init_term( %opt_term );
    my Int $sep_w = print-columns-ext( $thousands-separator, $color );
    my Int $longest = $digits + ( ( $digits - 1 ) div 3 ) * $sep_w;
    my Str $tab     = '  -  ';
    my Int $tab_w = print-columns( $tab );
    my Str $back_tmp;
    my Str $confirm_tmp;
    my Str @ranges;
    if $longest * 2 + $tab_w <= get-term-width() {
        @ranges = ( unicode-sprintf( '0', $longest, :1alignment, :$color )
                  ~ $tab
                  ~ unicode-sprintf( '9', $longest, :1alignment, :$color ) );
        for 1 .. $digits - 1 -> $zeros {
            my Str $begin = insert-sep( '1' ~ '0' x $zeros, $thousands-separator );
            my Str $end   = insert-sep( '9' ~ '0' x $zeros, $thousands-separator );
            @ranges.unshift: unicode-sprintf( $begin, $longest, :1alignment, :$color )
                           ~ $tab
                           ~ unicode-sprintf( $end,   $longest, :1alignment, :$color );
        }
        $back_tmp    = unicode-sprintf( $back,    $longest * 2 + $tab_w + 1, :$color );
        $confirm_tmp = unicode-sprintf( $confirm, $longest * 2 + $tab_w + 1, :$color );
    }
    else {
        @ranges = ( unicode-sprintf( '0', $longest, :$color ) );
        for 1 .. $digits - 1 -> $zeros { #
            my Str $begin = insert-sep( '1' ~ '0' x $zeros, $thousands-separator );
            @ranges.unshift: unicode-sprintf( $begin, $longest, :$color );
        }
        $back_tmp    = $back;
        $confirm_tmp = $confirm;
    }

    my @pre = ( Str, $confirm_tmp );
    my Int %numbers;
    my Str $result;

    NUMBER: loop {
        my Str $new_number = $result // '';
        my @tmp;
        if $info.chars {
            @tmp.push: $info;
        }
        my $row = sprintf( "{$cs-label}%*s", $longest, $new_number );
        if print-columns( $row ) > get-term-width() {
            $row = $new_number;
        }
        @tmp.push: $row;
        if $prompt.chars {
            @tmp.push: $prompt;
        }
        # Choose
        my Str $range = $!tc.choose(
            [ |@pre, |( $small-first ?? @ranges.reverse !! @ranges ) ],
            :prompt( @tmp.join: "\n" ), :2layout, :1alignment, :undef( $back_tmp ), :$tabs-prompt
        );
        if ! $range.defined {
            if $result.defined {
                $result = Str;
                %numbers = ();
                next NUMBER;
            }
            else {
                self!_end_term( %opt_term );
                return;
            }
        }
        elsif $range eq $confirm_tmp {
            self!_end_term( %opt_term );
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
        my Str @choices = $zeros ?? ( 1 .. 9 ).map( { $_ ~ '0' x $zeros } ) !! '0' .. '9';
        my Str $back_short = '<<';
        # Choose
        my $num = $!tc.choose(
            [ Str, |@choices, $reset ],
            :prompt( @tmp.join: "\n" ), :1layout, :2alignment, :0order, :undef( $back_short ), :$tabs-prompt
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
        Int_0_or_1 :$index          = $!index,
        Int_0_or_1 :$mouse          = $!mouse,
        Int_0_or_1 :$order          = $!order,
        Int_0_or_1 :$hide-cursor    = $!hide-cursor,
        Int_0_or_1 :$keep-chosen    = $!keep-chosen,
        Int_0_or_1 :$all-by-default = $!all-by-default,
        Int_0_to_2 :$clear-screen   = $!clear-screen,
        Int_0_to_2 :$color          = $!color,
        Int_0_to_2 :$alignment      = $!alignment,
        Int_0_to_2 :$layout         = 2,
        List       :$mark           = $!mark,
        List       :$tabs-info      = $!tabs-info,
        List       :$tabs-prompt    = $!tabs-prompt,
        Str        :$prefix         = $!prefix // '',
        Str        :$info           = $!info,
        Str        :$prompt         = 'Choose:',
        Str        :$cs-label       = $!cs-label // '', #/
        Str        :$cs-begin       = $!cs-begin;
        Str        :$cs-separator   = $!cs-separator;
        Str        :$cs-end         = $!cs-end;
        Str        :$back           = $!back,
        Str        :$confirm        = $!confirm,
        *%rest # old names warnings ###
    ) {
    self!_old_names_warnings( %rest ); # old names warnings ###
    my %opt_term = :$clear-screen, :$mouse, :$hide-cursor, :$color;
    self!_init_term( %opt_term );
    my List $new_idx = [];
    my List $new_val = [ @list ];
    my @pre = ( Int, $confirm );
    my List $initially_marked = [ |$mark.map: { $_ + @pre.elems } ];
    my @bu;

    loop {
        my @tmp;
        if $info.chars {
             @tmp.push: $info;
        }
        my $sofar;
        if $cs-label.defined {
            $sofar ~= $cs-label;
        }
        if $new_idx.elems {
            $sofar ~= $cs-begin ~ @list[|$new_idx].map( { $_ // '' } ).join( $cs-separator ) ~ $cs-end;
        }
        elsif $all-by-default {
            $sofar ~= $cs-begin ~ '*' ~ $cs-end;
        }
        if $sofar.defined {
            @tmp.push: $sofar;
        }
        if $prompt.chars {
            @tmp.push: $prompt;
        }
        my @choices = |@pre, |$new_val.map: { $prefix ~ $_.gist };
        # Choose
        my Int @idx = $!tc.choose-multi(
            @choices,
            :prompt( @tmp.join: "\n" ), :meta-items( |^@pre ), :undef( $back ), :lf( 0, ( $cs-label // '' ).chars ), # /
            :$alignment, :1index, :$layout, :$order, :mark( $initially_marked ), :2include-highlighted, :$tabs-prompt
        );
        if $initially_marked.defined {
            $initially_marked = List;
        }
        if ! @idx[0].defined || @idx[0] == 0 {
            if @bu {
                ( $new_val, $new_idx ) = @bu.pop;
                next;
            }
            self!_end_term( %opt_term );
            return;
        }
        @bu.push( [ [ |$new_val ], [ |$new_idx ] ] );
        my $ok;
        if @idx[0] == @pre.first( $confirm, :k ) {
            $ok = True;
            @idx.shift;
        }
        my Int @tmp_idx;
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
            self!_end_term( %opt_term );
            return $index ?? $new_idx !! [ @list[|$new_idx] ];
        }
    }
}


sub settings-menu ( @menu, %setup, *%opt ) is export( :DEFAULT, :settings-menu ) {
    Term::Choose::Util.new().settings-menu( @menu, %setup, |%opt );
}

method settings-menu ( @menu, %setup,
        Int_0_or_1 :$mouse                   = $!mouse,
        Int_0_or_1 :$hide-cursor             = $!hide-cursor,
        Int_0_to_2 :$clear-screen            = $!clear-screen,
        Int_0_to_2 :$color                   = $!color,
        Str        :$info                    = $!info,
        Str        :$prompt                  = 'Choose:',
        Str        :$back                    = $!back,
        Str        :$confirm                 = $!confirm,
        Str        :$cs-label                = $!cs-label,
        List       :$tabs-info               = $!tabs-info,
        *%rest # old names warnings ###
    ) {
    self!_old_names_warnings( %rest ); # old names warnings ###
    my %opt_term = :$clear-screen, :$mouse, :$hide-cursor, :$color;
    self!_init_term( %opt_term );
    my Int $longest = 0;
    my %name_w;
    my %new_setup;
    for @menu -> ( Str $key, Str $name, $ ) {
        %name_w{$key} = print-columns-ext( $name, $color );
        $longest max= %name_w{$key};
        %setup{$key} //= 0;
        %new_setup{$key} = %setup{$key};
    }
    my @pre = Int, $confirm;
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
        if $cs-label.defined {
            @tmp.push: $cs-label ~ %new_setup.keys.map({ "$_=%new_setup{$_}" }).join: ', ';
        }
        if $prompt.defined && $prompt.chars {
            @tmp.push: $prompt;
        }
        my $comb_prompt = @tmp.join: "\n";
        # Choose
        my Int $idx = $!tc.choose(
            [ |@pre, |@print_keys ],
            :$info, :prompt( $comb_prompt ), :1index, :$default, :2layout, :0alignment, :undef( $back ), :$tabs-info
        );
        if ! $idx {
            self!_end_term( %opt_term );
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
            self!_end_term( %opt_term );
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
    my $new = $<sign> // '';
    $new ~= $<int>.flip.comb( / . ** 1..3 / ).join( "\x[feff]\x[feff]" ).flip;
    $new.=subst( /"\x[feff]\x[feff]"/, $thousands-separator, :g ); # to preserve ansi color escapes in the thousands-separator
    $new ~= $<rest> // '';
    return $new;
}

sub unicode-sprintf ( Str $str, Int $avail_col_w, @cache?, :$alignment = 0, :$add_dots = 0, :$color = 0 ) is export( :unicode-sprintf ) {
    my Int $str_length = print-columns-ext( $str, $color );
    if $str_length > $avail_col_w {
        if $add_dots {
           return to-printwidth( $str, $avail_col_w - 3 ) ~ '...';
        }
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

sub print-columns-ext ( $str, Int $color ) { # Str $str
    if ( $color ) { # && $str ~~ Str
        return print-columns( $str.subst( / \e \[ <[\d;]>* m /, '', :g ) );
    }
    else {
        return print-columns( $str );
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

=head1 ROUTINES

Values in brackets are default values.

=head3 Options available for all subroutines

=item1 clear-screen

If enabled, the screen is cleared before the output.

Values: [0],1.

=item1 color

Enables the support for color and text formatting escape sequences.

Setting color to 1 enables the support for color and text formatting escape sequences except for the current selected
element. If set to 2, also for the current selected element the color support is enabled (inverted colors).

Values: [0],1,2.

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

=item1 cs-label

The value of I<cs-label> is a string which is placed in front of the "chosen so far" info output.

With C<settings-menu> the "chosen so far" info output is only shown if I<cs-label> is defined.

Defaults: C<choose-directories>: '> ', C<choose-a-directory>: 'Dir: ', C<choose-a-file>: 'File: ',
C<choose-a-number>: 'Dirs: ', C<choose-a-subset>: '', C<settings-menu>: undef

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

=item1 filter

If set, the value of this option is treated as a regex pattern.

Only files matching this pattern will be displayed.

The regex pattern is used as the value of C<dir>s C<:test> parameter.

=item1 show-files

Customize the string of the menu entry "show-files".

Default: C<[Show-Files]>

=head2 choose-directories

=begin code

    @chosen-directories = choose-directories( :layout(1), ... )

=end code

C<choose-directories> is similar to C<choose-a-directory> but it is possible to return multiple directories.

Use the "add-dirs" menu entry to add the current directory to the list of chosen directories.

To return the list of chosen directories select the "confirm" menu entry.

The "back" menu entry removes the last added directory. If the list of chosen directories is empty, "back" causes
choose-directories to return nothing.

Options as in L<#choose-a-directory> plus

=item1 add-dirs

Customize the string of the menu entry "add-dirs".

Default: C<[Add-Dir]>

=head2 choose-a-number

=begin code

    my $number = choose-a-number( 5, :cs-label<Testnumber>, ... );

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

=item1 all-by-default

If enabled, all elements are selected if C<CONFIRM> is chosen without any selected elements.

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

=item1 cs-begin

Info output: the I<cs-begin> string is placed between the I<cs-label> string and the
chosen elements as soon as an element has been chosen.

Default: empty string

=item1 cs-separator

Info output: I<cs-separator> is placed between the chosen list elements.

Default: C< ,>

=item1 cs-end

Info output: as soon as elements have been chosen the I<cs-end> string is placed at the end of the chosen elements.

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

Setting the option I<cs-label> to a defined value adds an info output line.

=head2 DEPRECATIONS

The use of C<choose-dirs> is deprecated - use C<choose-directories> instead.

The use of C<choose-a-dir> is deprecated - use C<choose-a-directory> instead.

The deprecated routine names will be removed.

=head2 RENAMED OPTIONS

    <Old names>:                <New names>:

    justify                     alignment

    dir                         init-dir

    up                          parent-dir

    name                        cs-label

    current-selection-label     cs-label

    sofar-begin                 cs-begin

    current-selection-begin     cs-begin

    sofar-separator             cs-separator

    current-selection-separator cs-separator

    sofar-end                   cs-end

    current-selection-end       cs-end

    thsd-sep                    thousands-separator

    add-dir                     add-dirs

Only the new option names work.

=head1 AUTHOR

Matthäus Kiem <cuer2s@gmail.com>

=head1 CREDITS

Thanks to the people from L<Perl-Community.de|http://www.perl-community.de>, from
L<stackoverflow|http://stackoverflow.com> and from L<#perl6 on irc.freenode.net|irc://irc.freenode.net/#perl6> for the
help.

=head1 LICENSE AND COPYRIGHT

Copyright 2016-2020 Matthäus Kiem.

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
