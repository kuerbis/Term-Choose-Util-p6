use v6;
unit class Term::Choose::Util:ver<1.3.9>;

use Term::Choose;
use Term::Choose::LineFold;
use Term::Choose::Screen;

subset Positive_Int of Int where * > 0;
subset Int_0_to_2   of Int where * == 0|1|2;
subset Int_0_or_1   of Int where * == 0|1;

has Int_0_or_1   $.all-by-default  = 0;
has Int_0_or_1   $.clear-screen    = 0;
has Int_0_or_1   $.hide-cursor     = 1;
has Int_0_or_1   $.index           = 0;
has Int_0_or_1   $.keep-chosen     = 0;
has Int_0_or_1   $.loop            = 0;
has Int_0_or_1   $.mouse           = 0;
has Int_0_or_1   $.order           = 1;
has Int_0_or_1   $.save-screen     = 0;
has Int_0_or_1   $.show-hidden     = 1;
has Int_0_or_1   $.small-first     = 0;
has Int_0_to_2   $.alignment       = 0;
has Int_0_to_2   $.color           = 0;
has Int_0_to_2   $.layout          = 1;
has Int_0_to_2   $.page            = 1; # no doc
has Positive_Int $.default-number;
has Positive_Int $.keep            = 5; # no doc
has List $.margin                  = [];
has List $.mark                    = [];
has List $.tabs-info               = [];
has List $.tabs-prompt             = [];
has Str $.back                     = 'BACK';
has Str $.confirm                  = 'CONFIRM';
has Str $.cs-begin                 = '';
has Str $.cs-label;
has Str $.cs-end                   = '';
has Str $.cs-separator             = ', ';
has Str $.filter;
has Str $.footer                   = ''; # no doc
has Str $.info                     = '';
has Str $.init-dir                 = $*HOME.Str;
has Str $.parent-dir               = '..';
has Str $.prefix                   = '';
has Str $.prompt                   = 'Your choice: ';
has Str $.thousands-separator      = ',';

# no doc:
has Str $.reset                    = 'reset';


method !_init_term ( *%opt ) {
    if %opt<hide-cursor> {
        print hide-cursor;
    }
    my Int $clear-screen = %opt<clear-screen>;
    if %opt<save-screen> {
        print save-screen;
        $clear-screen = 1;
    }
    if $clear-screen {
        print clear-screen();
    }
    else {
        print clear-to-end-of-screen();
    }
}


method !_end_term ( *%opt ) {
    if %opt<save-screen> {
        print restore-screen;
    }
    else {
        if ! $!loop {
            print clear-to-end-of-screen();
        }
    }
    if %opt<hide-cursor> && ! $!loop {
        print show-cursor;
    }
}


sub choose-directories ( *%opt ) is export( :DEFAULT, :choose-directories ) { Term::Choose::Util.new().choose-directories( |%opt ) }

method choose-directories (
        Int_0_or_1   :$clear-screen = $!clear-screen,
        Int_0_or_1   :$hide-cursor  = $!hide-cursor,
        Int_0_or_1   :$mouse        = $!mouse,
        Int_0_or_1   :$order        = $!order,
        Int_0_or_1   :$save-screen  = $!save-screen,
        Int_0_or_1   :$show-hidden  = $!show-hidden,
        Int_0_to_2   :$alignment    = $!alignment,
        Int_0_to_2   :$color        = $!color,
        Int_0_to_2   :$layout       = $!layout,
        Int_0_to_2   :$page         = $!page,
        Positive_Int :$keep         = $!keep;
        Str          :$back         = $!back,
        Str          :$confirm      = $!confirm,
        Str          :$cs-label     = $!cs-label // 'Chosen Dirs: ',
        Str          :$footer       = $!footer,
        Str          :$info         = $!info,
        Str          :$init-dir     = $!init-dir,
        Str          :$parent-dir   = $!parent-dir,
        Str          :$prompt       = $!prompt,
        List         :$margin       = $!margin,
        List         :$tabs-info    = $!tabs-info,
        List         :$tabs-prompt = $!tabs-prompt,
        --> Array[IO::Path]
    ) {
    self!_init_term( :$clear-screen, :$hide-cursor, :$save-screen );
    my List $local_tabs_prompt;
    if $tabs-prompt {
        $local_tabs_prompt = $tabs-prompt;
    }
    else {
        my Int $subseq_tab = 2;
        if $margin {
            $local_tabs_prompt = [ $margin[3], $margin[3] + $subseq_tab, $margin[1] ];
        }
        else {
            $local_tabs_prompt = [ 0, $subseq_tab, 0 ];
        }
    }
    my $tc = Term::Choose.new(
        :0clear-screen, :$color, :$footer, :0hide-cursor, :$keep, :1loop, :$margin,
        :$mouse, :$page :0save-screen, :$tabs-info, :tabs-prompt( $local_tabs_prompt )
    );
    my IO::Path @chosen_dirs; #
    my IO::Path $dir = $init-dir.IO;
    my IO::Path $prev_dir = $dir;
    my ( Str $confirm_mode, Str $change_path, Str $add_dirs ) = ( '  ' ~ $confirm, '- Change Location', '- Add Directories' );
    my @bu;

    CHOOSE_MODE: loop {
        my Str $key_dirs = $cs-label;
        my Str $dirs_chosen = $key_dirs ~ ( @chosen_dirs ?? join( ', ', @chosen_dirs ) !! '---' );
        my Str $key_path = 'Location: ';
        my Str $path = $key_path ~ $dir;
        my Str $mode_prompt = $dirs_chosen ~ "\n" ~ $path;
        # Choose
        my Str $choice = $tc.choose(
            [ Str, $confirm_mode, $change_path, $add_dirs ],
            :$info, :prompt( $mode_prompt ), :2layout, :undef( '  ' ~ $back )
        );
        if ! $choice.defined {
            if @bu.elems {
                my $tmp = @bu.pop;
                $dir = $tmp[0];
                @chosen_dirs = |$tmp[1];
                next CHOOSE_MODE;
            }
            self!_end_term( :$hide-cursor, :$save-screen );
            return Array[IO::Path].new();
        }
        elsif $choice eq $confirm_mode {
            self!_end_term( :$hide-cursor, :$save-screen );
            return @chosen_dirs;
        }
        elsif $choice eq $change_path {
            my Str $prompt_fmt = $key_path ~ "%s";
            if $prompt.chars {
                $prompt_fmt ~= "\n" ~ $prompt;
            }
            my %opt_path = :info( '' ), :$order, :$prompt, :$show-hidden, :$alignment, :$layout, :$init-dir,
                           :back( '<<' ), :confirm<OK>, :$parent-dir;
            my IO::Path $tmp_dir = self!_choose_a_path( $tc, $dir, $prompt_fmt, %opt_path );
            if $tmp_dir.defined {
                $dir = $tmp_dir;
            }
        }
        elsif $choice eq $add_dirs {
            my IO::Path @avail_dirs;
            try {
                if $show-hidden {
                    @avail_dirs = $dir.dir.grep({ .d }).sort;
                }
                else {
                    @avail_dirs = $dir.dir.grep({ .d && .basename !~~ / ^ \. / }).sort;
                }
                CATCH {
                    my $prompt = $dir ~ ":\n" ~ $_;
                    $tc.pause( [ 'Press ENTER to continue.' ], :$prompt );
                    next CHOOSE_MODE;
                }
            }
            my Str @tmp_cs_label;
            @tmp_cs_label.push: $dirs_chosen;
            @tmp_cs_label.push: $path;
            @tmp_cs_label.push: 'Dirs to add: ';
            # choose_a_subset
            my Int @idxs = self.choose-a-subset(
                @avail_dirs.map({ .basename }).sort,
                :$info, :$prompt, :back( '<<' ), :$color, :confirm( 'OK' ), :cs-begin( '' ),
                :cs-label( @tmp_cs_label.join: "\n" ), :$page, :$footer, :$keep, :1index, :0hide-cursor,
                :0clear-screen, :$margin, :$tabs-info, :tabs-prompt( $local_tabs_prompt )
            );
            if @idxs.elems {
                @bu.push: [ $dir, [ |@chosen_dirs ] ];
                @chosen_dirs.push: |@avail_dirs[@idxs];
            }
        }
    }
}


sub choose-a-directory ( *%opt ) is export( :DEFAULT, :choose-a-directory ) { Term::Choose::Util.new().choose-a-directory( |%opt ) }

method choose-a-directory (
        Int_0_or_1   :$clear-screen = $!clear-screen,
        Int_0_or_1   :$hide-cursor  = $!hide-cursor,
        Int_0_or_1   :$mouse        = $!mouse,
        Int_0_or_1   :$order        = $!order,
        Int_0_or_1   :$save-screen  = $!save-screen,
        Int_0_or_1   :$show-hidden  = $!show-hidden,
        Int_0_to_2   :$alignment    = $!alignment,
        Int_0_to_2   :$color        = $!color,
        Int_0_to_2   :$layout       = $!layout,
        Int_0_to_2   :$page         = $!page,
        Positive_Int :$keep         = $!keep;
        Str          :$init-dir     = $!init-dir,
        Str          :$info         = $!info,
        Str          :$prompt       = $!prompt,
        Str          :$cs-label     = $!cs-label // 'Directory: ',
        Str          :$footer       = $!footer,
        Str          :$back         = $!back,
        Str          :$confirm      = $!confirm,
        Str          :$parent-dir   = $!parent-dir,
        List         :$margin       = $!margin,
        List         :$tabs-info    = $!tabs-info,
        List         :$tabs-prompt  = $!tabs-prompt,
        --> IO::Path
    ) {
    self!_init_term( :$clear-screen, :$hide-cursor, :$save-screen );
    my List $local_tabs_prompt = $margin && ! $tabs-prompt ?? $margin[3,3,1] !! $tabs-prompt;
    my $tc = Term::Choose.new(
        :0clear-screen, :$color, :$footer, :0hide-cursor, :$keep, :1loop, :$margin,
        :$mouse, :$page :0save-screen, :$tabs-info, :tabs-prompt( $local_tabs_prompt )
    );
    my IO::Path $dir = $init-dir.IO;
    my %opt_path = :$order, :$show-hidden, :$alignment, :$layout, :$info, :$prompt, :$back, :$confirm, :$parent-dir,
                   :$back, :$confirm;
    my Str $prompt_fmt = $cs-label ~ "%s";
    if $prompt.chars {
        $prompt_fmt ~= "\n" ~ $prompt;
    }
    my IO::Path $chosen_dir = self!_choose_a_path( $tc, $dir, $prompt_fmt, %opt_path );
    self!_end_term( :$hide-cursor, :$save-screen );
    return $chosen_dir
}


sub choose-a-file ( *%opt ) is export( :DEFAULT, :choose-a-file ) { Term::Choose::Util.new().choose-a-file( |%opt ) }

method choose-a-file (
        Int_0_or_1   :$clear-screen = $!clear-screen,
        Int_0_or_1   :$hide-cursor  = $!hide-cursor,
        Int_0_or_1   :$mouse        = $!mouse,
        Int_0_or_1   :$order        = $!order,
        Int_0_or_1   :$save-screen  = $!save-screen,
        Int_0_or_1   :$show-hidden  = $!show-hidden,
        Int_0_to_2   :$alignment    = $!alignment,
        Int_0_to_2   :$color        = $!color,
        Int_0_to_2   :$layout       = $!layout,
        Int_0_to_2   :$page         = $!page,
        Positive_Int :$keep         = $!keep;
        Str          :$filter       = $!filter,
        Str          :$init-dir     = $!init-dir,
        Str          :$info         = $!info,
        Str          :$prompt       = $!prompt,
        Str          :$cs-label     = $!cs-label // 'File: ',
        Str          :$footer       = $!footer,
        Str          :$back         = $!back,
        Str          :$confirm      = $!confirm,
        Str          :$parent-dir   = $!parent-dir,
        List         :$margin       = $!margin,
        List         :$tabs-info    = $!tabs-info,
        List         :$tabs-prompt  = $!tabs-prompt,
        --> IO::Path
    ) {
    self!_init_term( :$clear-screen, :$hide-cursor, :$save-screen );
    my List $local_tabs_prompt = $margin && ! $tabs-prompt ?? $margin[3,3,1] !! $tabs-prompt;
    my $tc = Term::Choose.new(
        :0clear-screen, :$color, :$footer, :0hide-cursor, :$keep, :1loop, :$margin,
        :$mouse, :$page :0save-screen, :$tabs-info, :tabs-prompt( $local_tabs_prompt )
    );
    my IO::Path $dir = $init-dir.IO;
    my %opt_path = :$order, :$show-hidden, :$alignment, :$layout, :$info, :$prompt, :$cs-label, :back( '<<' ),
                   :confirm<OK>, :$parent-dir, :$filter;
    my %opt_file = %opt_path;
    %opt_file<back> = $back;
    %opt_file<confirm> = $confirm;
    CHOOSE_DIR: loop {
        my Str $prompt_fmt = "File-Directory: %s";
        if $prompt.chars {
            $prompt_fmt ~= "\n" ~ $prompt;
        }
        my IO::Path $chosen_dir = self!_choose_a_path( $tc, $dir, $prompt_fmt, %opt_path );
        if ! $chosen_dir.defined {
            self!_end_term( :$hide-cursor, :$save-screen );
            return IO::Path;
        }
        my IO::Path $chosen_file = self!_a_file( $tc, $chosen_dir, %opt_file );
        if ! $chosen_file.defined {
            next CHOOSE_DIR;
        }
        self!_end_term( :$hide-cursor, :$save-screen );
        return $chosen_file;
    }
}


method !_choose_a_path ( $tc, IO::Path $dir, Str $prompt_fmt, %opt --> IO::Path ) {
    my IO::Path $curr_dir = $dir;
    my IO::Path $prev_dir = $dir;

    loop {
        my IO::Path @dirs;
        try {
            if %opt<show-hidden> {
                @dirs = $curr_dir.dir.grep({ .d }).sort;
            }
            else {
                @dirs = $curr_dir.dir.grep({ .d && .basename !~~ / ^ \. / }).sort;
            }
            CATCH {
                my Str $prompt = $curr_dir.gist ~ ":\n" ~ $_;
                $tc.pause( [ 'Press ENTER to continue.' ], :$prompt );
                if $curr_dir.Str eq '/' {
                    return;
                }
                $curr_dir = $curr_dir.dirname.IO;
                next;
            }
        }
        my Str $parent_dir = %opt<parent-dir>;
        my Str $confirm = %opt<confirm>;
        my @pre = ( Int, $confirm, $parent_dir );
        my Str $prompt = sprintf $prompt_fmt, $prev_dir;
        my @choices = |@pre, |@dirs.map( { .basename } );
        # Choose
        my Int $idx = $tc.choose(
            @choices,
            :info( %opt<info> ), :$prompt, :1index, :0default, :alignment( %opt<alignment> ), :layout( %opt<layout> ),
            :order( %opt<order> ), :undef( %opt<back> )
        );
        if ! $idx.defined || ! @choices[$idx].defined {
            return IO::Path;
        }
        elsif @choices[$idx] eq %opt<confirm> {
            return $prev_dir;
        }
        elsif @choices[$idx] eq %opt<parent-dir> {
            $curr_dir = $curr_dir.dirname.IO;
        }
        else {
            $curr_dir = @dirs[$idx-@pre];
        }
        $prev_dir = $curr_dir;
    }
}


method !_a_file ( $tc, IO::Path $dir, %opt --> IO::Path ) {
    my Str $prev_dir;
    my Str $chosen_file;

    loop {
        my Str @files;
        try {
            if %opt<filter> {
                my Str $regex = %opt<filter>;
                @files = $dir.dir( :test( / <$regex> / ) ).grep( { .f } ).map: { .basename };
            }
            else {
                @files = $dir.dir(                       ).grep( { .f } ).map: { .basename };
            }
            if ! %opt<show-hidden> {
                @files = @files.grep: { ! / ^ \. / };
            }
            CATCH { #
                my Str $prompt = $dir.gist ~ ":\n" ~ $_;
                $tc.pause( [ 'Press ENTER to continue.' ], :$prompt );
                return;
            }
        }
        if ! @files.elems {
            my $prompt = "Dir: $dir\nNo files in this directory" ~ ( %opt<filter> ?? " which match filter %opt<filter>." !! "." );
            $tc.pause(
                [ ' < ' ],
                :$prompt, :info( %opt<info> )
            );
            return;
        }
        my Str @tmp_prompt;
        @tmp_prompt.push: 'File-Directory: ' ~ $dir;
        @tmp_prompt.push: %opt<cs-label> ~ ( ($prev_dir//'').chars ?? $prev_dir !! '' );
        if %opt<prompt>.chars {
            @tmp_prompt.push: %opt<prompt>;
        }
        my Str $prompt = @tmp_prompt.join: "\n";
        my @pre = ( Str );
        if $chosen_file {
            @pre.push: %opt<confirm>;
        }
        # Choose
        $chosen_file = $tc.choose(
            [ |@pre, |@files.sort ],
            :info( %opt<info> ), :$prompt, :alignment( %opt<alignment> ), :layout( %opt<layout> ),
            :order( %opt<order> ), :undef( %opt<back> )
        );
        if ! $chosen_file.defined || ! $chosen_file.chars {
            if ( $prev_dir.defined ) { # chars
                $prev_dir = Str;
                next;
            }
            return IO::Path;
        }
        elsif $chosen_file eq %opt<confirm> {
            return if ! $prev_dir.defined; # chars
            return $dir.add: $prev_dir;
        }
        else {
            $prev_dir = $chosen_file;
        }
    }
}


sub choose-a-number ( Int $digits = 7, *%opt ) is export( :DEFAULT, :choose-a-number ) {
    Term::Choose::Util.new().choose-a-number( $digits, |%opt );
}

method choose-a-number ( Int $digits = 7,
        Int_0_or_1   :$clear-screen        = $!clear-screen,
        Int_0_or_1   :$hide-cursor         = $!hide-cursor,
        Int_0_or_1   :$mouse               = $!mouse,
        Int_0_or_1   :$save-screen         = $!save-screen,
        Int_0_or_1   :$small-first         = $!small-first,
        Int_0_to_2   :$color               = $!color,
        Int_0_to_2   :$page                = $!page,
        Positive_Int :$keep                = $!keep;
        Positive_Int :$default-number      = $!default-number,
        Str          :$info                = $!info,
        Str          :$prompt              = $!prompt,
        Str          :$cs-label            = $!cs-label,
        Str          :$footer              = $!footer,
        Str          :$thousands-separator = $!thousands-separator,
        Str          :$back                = $!back,
        Str          :$confirm             = $!confirm,
        Str          :$reset               = $!reset,
        List         :$margin              = $!margin,
        List         :$tabs-info           = $!tabs-info,
        List         :$tabs-prompt         = $!tabs-prompt,
        --> Int
    ) {
    self!_init_term( :$clear-screen, :$hide-cursor, :$save-screen );
    my List $local_tabs_prompt = $margin && ! $tabs-prompt ?? $margin[3,3,1] !! $tabs-prompt;
    my $tc = Term::Choose.new(
        :0clear-screen, :$color, :$footer, :0hide-cursor, :$keep, :1loop, :$margin,
        :$mouse, :$page :0save-screen, :$tabs-info, :tabs-prompt( $local_tabs_prompt )
    );
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
    my Int %numbers;
    my Str $result = '';
    if $default-number.defined && $default-number.chars <= $digits {
        my Int $count_zeros = 0;
        for |$default-number.comb.reverse -> $d {
            %numbers{$count_zeros} = $d * 10 ** $count_zeros;
            $count_zeros++;
        }
        $result = %numbers.values.sum.Str;
        $result = insert-sep( $result, $thousands-separator );
    }

    NUMBER: loop {
        my Str $cs_row;
        if $cs-label.defined || $result.chars {
            $cs_row = sprintf(  "%s%*s", $cs-label // '', $longest, $result ); #/
            if print-columns( $cs_row ) > get-term-width() {
                $cs_row = $result;
            }
        }
        my Str @tmp_prompt;
        if $cs_row.defined {
            @tmp_prompt.push: $cs_row;
        }
        if $prompt.chars {
            @tmp_prompt.push: $prompt;
        }
        my @pre = ( Str, $confirm_tmp );
        # Choose
        my Str $range = $tc.choose(
            [ |@pre, |( $small-first ?? @ranges.reverse !! @ranges ) ],
            :prompt( @tmp_prompt.join: "\n" ), :$info, :2layout, :1alignment, :undef( $back_tmp )
        );
        if ! $range.defined {
            if $result.chars {
                $result = '';
                %numbers = ();
                next NUMBER;
            }
            else {
                self!_end_term( :$hide-cursor, :$save-screen );
                return Int;
            }
        }
        elsif $range eq $confirm_tmp {
            self!_end_term( :$hide-cursor, :$save-screen );
            if ! $result.chars {
                return Int;
            }
            $result.=subst( / $thousands-separator /, '', :g ) if $thousands-separator ne '';
            return $result.Int;
        }
        my Str $begin = ( $range.split( /\s+ '-' \s+/ ) )[0];
        my Int $zeros;
        if $thousands-separator.chars {
            $zeros = $begin.trim-leading.subst( / $thousands-separator /, '', :g ).chars - 1;
        }
        else {
            $zeros = $begin.trim-leading.chars - 1;
        }
        my Str @choices = $zeros ?? ( 1 .. 9 ).map( { $_ ~ '0' x $zeros } ) !! '0' .. '9';
        my Str $back_short = '<<';
        @pre = ( Str );
        # Choose
        my Str $num = $tc.choose(
            [ |@pre, |@choices, $reset ],
            :prompt( @tmp_prompt.join: "\n" ), :$info, :1layout, :2alignment, :0order, :undef( $back_short )
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
        Int_0_or_1 :$all-by-default = $!all-by-default,
        Int_0_or_1 :$clear-screen   = $!clear-screen,
        Int_0_or_1 :$hide-cursor    = $!hide-cursor,
        Int_0_or_1 :$index          = $!index,
        Int_0_or_1 :$keep-chosen    = $!keep-chosen,
        Int_0_or_1 :$mouse          = $!mouse,
        Int_0_or_1 :$order          = $!order,
        Int_0_or_1 :$save-screen    = $!save-screen,
        Int_0_to_2 :$alignment      = $!alignment,
        Int_0_to_2 :$color          = $!color,
        Int_0_to_2 :$layout         = $!layout,
        Int_0_to_2 :$page           = $!page,
        Positive_Int :$keep         = $!keep;
        List       :$margin         = $!margin,
        List       :$mark           = $!mark,
        List       :$tabs-info      = $!tabs-info,
        List       :$tabs-prompt    = $!tabs-prompt,
        Str        :$prefix         = $!prefix,
        Str        :$info           = $!info,
        Str        :$prompt         = $!prompt,
        Str        :$cs-label       = $!cs-label,
        Str        :$cs-begin       = $!cs-begin,
        Str        :$cs-separator   = $!cs-separator,
        Str        :$cs-end         = $!cs-end,
        Str        :$back           = $!back,
        Str        :$confirm        = $!confirm,
        Str        :$footer         = $!footer,
        --> Array
    ) {
    self!_init_term( :$clear-screen, :$hide-cursor, :$save-screen );
    my List $local_tabs_prompt;
    if $tabs-prompt {
        $local_tabs_prompt = $tabs-prompt;
    }
    else {
        my Int $subseq_tab = $cs-label.defined ?? 2 !! 0;
        if $margin {
            $local_tabs_prompt = [ $margin[3], $margin[3] + $subseq_tab, $margin[1] ];
        }
        elsif $subseq_tab {
            $local_tabs_prompt = [ 0, $subseq_tab, 0 ];
        }
    }
    my $tc = Term::Choose.new(
        :0clear-screen, :$color, :$footer, :0hide-cursor, :$keep, :1loop, :$margin,
        :$mouse, :$page :0save-screen, :$tabs-info, :tabs-prompt( $local_tabs_prompt )
    );
    my Array[Int] $new_idx = Array[Int].new(); # $new_idx is now defined
    my Array $new_val = [ @list ];
    my @pre = ( Int, $confirm );
    my @initially_marked = $mark.map: { $_ + @pre.elems };
    my @bu;

    loop {
        my Str @tmp_prompt;
        my Str $cs;
        if $cs-label.defined {
            $cs ~= $cs-label;
        }
        if $new_idx.elems {
            $cs ~= $cs-begin ~ @list[|$new_idx].map( { $_ // '' } ).join( $cs-separator ) ~ $cs-end;
        }
        elsif $all-by-default {
            $cs ~= $cs-begin ~ '*' ~ $cs-end;
        }
        if $cs.defined {
            @tmp_prompt.push: $cs;
        }
        if $prompt.chars {
            @tmp_prompt.push: $prompt;
        }
        my @choices = |@pre, |$new_val.map: { $prefix ~ $_.gist };
        # Choose
        my Int @idx = $tc.choose-multi(
            @choices,
            :prompt( @tmp_prompt.join: "\n" ), :$info, :meta-items( |^@pre ), :undef( $back ), :$alignment,
            :1index, :$layout, :$order, :mark( @initially_marked ), :2include-highlighted
        );
        if @initially_marked.elems {
            @initially_marked = ();
        }
        if ! @idx[0].defined || @idx[0] == 0 {
            if @bu.elems {
                ( $new_val, $new_idx ) = @bu.pop;
                next;
            }
            self!_end_term( :$hide-cursor, :$save-screen );
            return $index ?? Array[Int].new() !! Array.new();
        }
        @bu.push( [ [ |$new_val ], Array[Int].new( |$new_idx ) ] );
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
            self!_end_term( :$hide-cursor, :$save-screen );
            return $index ?? @$new_idx !! Array.new( @list[|$new_idx] );
        }
    }
}


sub settings-menu ( @menu, %setup, *%opt ) is export( :DEFAULT, :settings-menu ) {
    Term::Choose::Util.new().settings-menu( @menu, %setup, |%opt );
}

method settings-menu ( @menu, %setup,
        Int_0_or_1 :$clear-screen = $!clear-screen,
        Int_0_or_1 :$hide-cursor  = $!hide-cursor,
        Int_0_or_1 :$mouse        = $!mouse,
        Int_0_or_1 :$save-screen  = $!save-screen,
        Int_0_to_2 :$color        = $!color,
        Int_0_to_2 :$page         = $!page,
        Positive_Int :$keep       = $!keep;
        Str        :$info         = $!info,
        Str        :$prompt       = $!prompt,
        Str        :$back         = $!back,
        Str        :$confirm      = $!confirm,
        Str        :$cs-label     = $!cs-label,
        Str        :$cs-begin     = $!cs-begin,
        Str        :$cs-separator = $!cs-separator,
        Str        :$cs-end       = $!cs-end,
        Str        :$footer       = $!footer,
        List       :$margin       = $!margin,
        List       :$tabs-info    = $!tabs-info,
        List       :$tabs-prompt  = $!tabs-prompt,
    ) {
    self!_init_term( :$clear-screen, :$hide-cursor, :$save-screen );
    my List $local_tabs_prompt = $margin && ! $tabs-prompt ?? $margin[3,3,1] !! $tabs-prompt;
    my $tc = Term::Choose.new(
        :0clear-screen, :$color, :$footer, :0hide-cursor, :$keep, :1loop, :$margin,
        :$mouse, :$page :0save-screen, :$tabs-info, :tabs-prompt( $local_tabs_prompt )
    );
    my Int $longest = 0;
    my Int %name_w;
    my Int %new_setup;
    for @menu -> ( Str $key, Str $name, $ ) {
        %name_w{$key} = print-columns-ext( $name, $color );
        $longest max= %name_w{$key};
        %setup{$key} //= 0;
        %new_setup{$key} = %setup{$key};
    }
    my Str @print_keys;
    for @menu -> ( Str $key, Str $name, @values ) {
        my $current = @values[%new_setup{$key}];
        @print_keys.push: $name ~ ( ' '  x ( $longest - %name_w{$key} ) ) ~ " [$current]";
    }
    %*ENV<TC_RESET_AUTO_UP> = 0;
    my Int $default = 0;
    my Int $count = 0;

    loop {
        my Str $cs;
        if $cs-label.defined {
            $cs = $cs-label ~ $cs-begin ~ %new_setup.keys.map({ "$_=%new_setup{$_}" }).join( $cs-separator ) ~ $cs-end;
        }
        my Str @tmp_prompt;
        if $cs.defined {
            @tmp_prompt.push: $cs;
        }
        if $prompt.chars {
            @tmp_prompt.push: $prompt;
        }
        my Str $comb_prompt = @tmp_prompt.join: "\n";
        my @pre = Int, $confirm;
        # Choose
        my Int $idx = $tc.choose(
            [ |@pre, |@print_keys ],
            :$info, :prompt( $comb_prompt ), :1index, :$default, :2layout, :0alignment, :undef( $back )
        );
        if ! $idx {
            self!_end_term( :$hide-cursor, :$save-screen );
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
            self!_end_term( :$hide-cursor, :$save-screen );
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

    my $new = Term::Choose::Util.new( :mouse( 1 ), ... )

=end code

=head1 ROUTINES

Values in brackets are default values.

=head3 Options available for all subroutines

=item1 back

Customize the string of the menu entry "back".

Default: C<BACK>

=item1 clear-screen

If enabled, the screen is cleared before the output.

Values: [0],1.

=item1 color

Enables the support for color and text formatting escape sequences.

Setting color to 1 enables the support for color and text formatting escape sequences except for the current selected
element. If set to 2, also for the current selected element the color support is enabled (inverted colors).

Values: [0],1,2.

=item1 confirm

Customize the string of the menu entry "confirm".

Default: C<CONFIRM>.

=item1 cs-label

The value of I<cs-label> (current selection label) is a string which is placed in front of the current selection.

Defaults: C<choose-directories>: 'Chosen Dirs: ', C<choose-a-directory>: 'Directory: ', C<choose-a-file>: 'File: '. For
C<choose-a-number>, C<choose-a-subset> and C<settings-menu> the default is undefined.

The current-selection output is placed between the info string and the prompt string.

=item1 hide-cursor

Hide the cursor

Values: 0,[1].

=item1 info

A string placed on top of of the output.

Default: undef

=item1 margin

The option I<margin> allows one to set a margin on all four sides.

I<margin> expects a reference to an array with four elements in the following order:

- top margin (number of terminal lines)

- right margin (number of terminal columns)

- botton margin (number of terminal lines)

- left margin (number of terminal columns)

I<margin> does not affect the I<info> string. To add margins to the I<info> string see I<tabs-info>.

I<margin> changes the default values of I<tabs-prompt>.

Allowed values: 0 or greater. Elements beyond the fourth are ignored.

Default: undef

=item1 mouse

Enable the mouse mode. An item can be chosen with the left mouse key, the right mouse key can be used instead of the
SpaceBar key.

Values: [0],1.

=item1 prompt

A string placed on top of the available choices.

Default: undef

=item1 save-screen

0 - off (default)

1 - use the alternate screen

=item1 tabs-info

The option I<tabs-info> allows one to insert spaces at the beginning and the end of I<info> lines.

I<tabs-info> expects a reference to an array with one to three elements:

- the first element (initial tab) sets the number of spaces inserted at beginning of paragraphs

- the second element (subsequent tab) sets the number of spaces inserted at the beginning of all broken lines apart from
the beginning of paragraphs

- the third element sets the number of spaces used as a right margin.

Allowed values: 0 or greater. Elements beyond the third are ignored.

Default: undef

=item1 tabs-prompt

The option I<tabs-prompt> allows one to insert spaces at the beginning and the end of the current-selection and
I<prompt> lines.

I<tabs-prompt> expects a reference to an array with one to three elements:

- the first element (initial tab) sets the number of spaces inserted at beginning of paragraphs

- the second element (subsequent tab) sets the number of spaces inserted at the beginning of all broken lines apart from
the beginning of paragraphs

- the third element sets the number of spaces used as a right margin.

Allowed values: 0 or greater. Elements beyond the third are ignored.

default: If I<margin> is defined, C<initial tab> and C<subsequent tab> are set to C<left-margin> and the right margin is
set to C<right-margin>. C<choose-directories> and C<choose-a-subset>: C<+2> for the C<subsequent tab>. Else the default
of I<tabs-prompt> is undefined.

=head2 choose-a-directory

=begin code

    my $chosen-directory = choose-a-directory( :1layout, ... )

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

Default: C<..>

=item1 L<#Options available for all subroutines>

=head2 choose-a-file

=begin code

    my $chosen-file = choose-a-file( :1layout, ... )

=end code

Choose the file directory and then choose a file from the chosen directory. To return the chosen file select the
"I<confirm>" menu entry.

Options as in L<#choose-a-directory> plus

=item1 filter

If set, the value of this option is treated as a regex pattern.

Only files matching this pattern will be displayed.

The regex pattern is used as the value of C<dir>s C<:test> parameter.

=head2 choose-directories

=begin code

    my @chosen-directories = choose-directories( :1layout, ... )

=end code

C<choose-directories> is similar to C<choose-a-directory> but it is possible to return multiple directories.

Options as in L<#choose-a-directory>.

=head2 choose-a-number

=begin code

    my $number = choose-a-number( 5, :cs-label<Testnumber>, ... );

=end code

This function lets you choose/compose a number (unsigned integer) which is then returned.

The fist argument is an integer and determines the range of the available numbers. For example setting the
first argument to C<4> would offer a range from C<0> to C<9999>. If not set, it defaults to C<7>.

Options:

=item1 default-number

Set a default number (unsigned integer in the range of the available numbers).

Default: undef

=item1 small-first

Put the small number ranges on top.

=item1 thousands-separator

Sets the thousands separator.

Default: C<,>

=item1 L<#Options available for all subroutines>

=head2 choose-a-subset

=begin code

    my $subset = choose-a-subset( @available-items, :1layout, ... )

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

Options:

=item1 cs-begin

Info output: the I<cs-begin> string is placed between the I<cs-label> string and the
key-value pairs.

Default: empty string

=item1 cs-separator

Info output: I<cs-separator> is placed between the key-value pairs.

Default: C< ,>

=item1 cs-end

Info output: the I<cs-end> string is placed at the end of the key-value pairs.

Default: empty string

=item1 L<#Options available for all subroutines>

The info output line is only shown if the option I<cs-label> is set to a defined value.

When C<settings-menu> is called, it displays for each list entry a row with the prompt string and the current value.

It is possible to scroll through the rows. If a row is selected, the set and displayed value changes to the next.After
scrolling through the list once the cursor jumps back to the top row.

If the "back" menu entry is chosen, C<settings-menu> does not apply the made changes and returns nothing. If the
"confirm" menu entry is chosen, C<settings-menu> applies the made changes in place to the passed configuration hash
(second argument) and returns the number of made changes.

=head1 AUTHOR

Matthäus Kiem <cuer2s@gmail.com>

=head1 CREDITS

Thanks to the people from L<Perl-Community.de|http://www.perl-community.de>, from
L<stackoverflow|http://stackoverflow.com> and from L<#perl6 on irc.freenode.net|irc://irc.freenode.net/#perl6> for the
help.

=head1 LICENSE AND COPYRIGHT

Copyright 2016-2022 Matthäus Kiem.

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
