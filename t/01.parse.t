use Test::More tests => 12;

BEGIN {
    use_ok( 'XML::Descent' );
}

my $xml = <<EOX;
<config>
    <favourites>
        <folder name="Me">
            <url name="Hexten">http://hexten.net/</url>
        </folder>
        <folder name="Programming">
            <url name="Source code search">http://www.koders.com/</url>
            <folder name="Perl">
                <url name="CPAN Search">http://search.cpan.org/</url>
                <url name="Perl Documentation">http://perldoc.perl.org/</url>
            </folder>
            <folder name="Ruby">
                <url name="Ruby Home">http://www.ruby-lang.org/</url>
            </folder>
        </folder>
    </favourites>
    <?horse?>
    <meta>
        <title>Frog fleening</title>
        <body>The body text is just <a href="http://www.w3.org/MarkUp/">HTML</a>.</body>
        <url>http://cpan.hexten.net/</url>
        <ignored>This text is ignored</ignored>
        <handled>This has a handler which doesn't recursively parse the contents</handled>
        <tokenised>This is <i>tokenised</i>.</tokenised>
    </meta>
</config>
EOX

# Trailing newline causes problems
chomp $xml;

#### Test xml() returns original source

my $p1 = XML::Descent->new({ Input => \$xml });
my $o1 = $p1->xml();

is($o1, $xml, 'unparsed XML');

#### Test text() returns all text

(my $text = $xml) =~ s/<[^>]+>//g;
my $p2 = XML::Descent->new({ Input => \$xml });
my $o2 = $p2->text();

is($o2, $text, 'extracted text');

#### Global extract tag contents

my @furls = $xml =~ />(http:.+?)</g;
my $p3 = XML::Descent->new({ Input => \$xml });
my @gurls = ( );
$p3->on(url => sub {
    push @gurls, $p3->text();
});
$p3->walk();

is_deeply(\@gurls, \@furls, 'extract urls');

#### Get all elements

my @felem = $xml =~ /<(\w+)/g;
my $p4 = XML::Descent->new({ Input => \$xml });
my @gelem = ( );
$p4->on('*' => sub {
    my ($elem, $attr) = @_;
    push @gelem, $elem;
    $p4->walk();
});
$p4->walk();

is_deeply(\@gelem, \@felem, 'all elements');

#### Global extract attribute

my @fnames = $xml =~ /name=\"(.*?)\"/g;
my $p5 = XML::Descent->new({ Input => \$xml });
my @gnames = ( );
$p5->on('*' => sub {
    my ($elem, $attr) = @_;
    push @gnames, $attr->{name} if exists $attr->{name};
    $p5->walk();
});
$p5->walk();

is_deeply(\@gnames, \@fnames, 'extracted attributes');

#### Extract inner XML
my @fmeta = $xml =~ m{<meta>(.*?)</meta>}sm;
my $gmeta = undef;
my $p6 = XML::Descent->new({ Input => \$xml });
$p6->on(meta => sub {
    $gmeta = $p6->xml();
});
$p6->walk();

is($gmeta, $fmeta[0], 'extract inner XML');

#### Extract inner text

(my $ftext = $fmeta[0]) =~ s/<.+?>//g;
my $gtext = undef;
my $p7 = XML::Descent->new({ Input => \$xml });
$p7->on(meta => sub {
    $gtext = $p7->text();
});
$p7->walk();

is($gtext, $ftext, 'extract inner text');

#### Test get_tok

my $ftag = bless([ 'E', 'url', '</url>' ], 'XML::TokeParser::Token');
my $p8 = XML::Descent->new({ Input => \$xml });
my $gtag = undef;
$p8->on(favourites => sub {
    TOK: while (my $tok = $p8->get_token()) {
        if ($tok->[0] eq 'E') {
            $gtag = $tok;
            last TOK;
        }
    }
});
my $gmeta2 = 0;
$p8->on(meta => sub {
    $gmeta2++;
});
$p8->walk();

is_deeply($gtag, $ftag, 'get_token');
is($gmeta2, 1, 'found meta');

#### Test paths

my @path  = ( );
my @fpath = ( );
while ($xml =~ m{<(/?[a-z]+)}g) {
    my $tag = $1;
    if ($tag =~ m{^/}) {
        pop @path;
    } else {
        push @path, $tag;
        push @fpath, '/' . join('/', @path);
    }
}
my @gpath = ( );
my $p9 = XML::Descent->new({ Input => \$xml });
$p9->on('*' => sub {
    push @gpath, $p9->get_path();
    $p9->walk();
});
$p9->walk();

is_deeply(\@gpath, \@fpath, 'get_path()');

#### Test stash

my $p10 = XML::Descent->new({ Input => \$xml });
$p10->on(folder => sub {
    my ($elem, $attr) = @_;

    $p10->on(url => sub {
        my ($elem, $attr) = @_;
        my $link = {
            name    => $attr->{name},
            url     => $p10->text()
        };
        $p10->stash(link => $link);
    });

    my $folder = $p10->walk();
    $folder->{name} = $attr->{name};

    $p10->stash(folder => $folder);
});
my $gstruc = $p10->walk();

$fstruc = { 'folder' => [ { 'link' => [ { 'url' => 'http://hexten.net/', 'name' => 'Hexten' } 
          ], 'name' => 'Me' }, { 'link' => [ { 'url' => 'http://www.koders.com/', 
          'name' => 'Source code search' } ], 'name' => 'Programming', 'folder' => [ { 
          'link' => [ { 'url' => 'http://search.cpan.org/', 'name' => 'CPAN Search' }, 
          { 'url' => 'http://perldoc.perl.org/', 'name' => 'Perl Documentation' } ], 
          'name' => 'Perl' }, { 'link' => [ { 'url' => 'http://www.ruby-lang.org/', 
          'name' => 'Ruby Home' } ], 'name' => 'Ruby' } ] } ] };

is_deeply($gstruc, $fstruc, 'stash');
