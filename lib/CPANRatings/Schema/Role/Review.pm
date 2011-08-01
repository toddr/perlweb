package CPANRatings::Schema::Role::Review;
use Moose::Role;
use String::Truncate qw(elide);
use Combust::Util qw(escape_html);
use namespace::clean;

has '_helpful_total' => (
    is      => 'rw',
    isa     => 'Int',
);

has '_helpful_yes' => (
    is      => 'rw',
    isa     => 'Int',
);

sub user_name {
    my $self = shift;
    $self->user->name || $self->user->username;
}

# temporary until everything is changed to use DBIx::Class methods
sub dbh {
    shift->result_source->storage->dbh;
}

sub update_helpful_score {
    my $self = shift;
    my $score = $self->_calculate_helpful_score;
    $self->helpful_score($score);
    $self->update;
}

sub _calculate_helpful_score {
    my $self = shift;
    my $total = $self->helpful_total;
    my $yes   = $self->helpful_yes;
    return 1 unless $total >= 4;
    my $p     = ( 100 / $total * $yes );
    return -1 if $p < 30;
    return 1;
}

sub add_helpful {
    my $self = shift;
    my $args = shift;
    $args->{helpful} = undef unless $args->{helpful};
    my $rv = 0;

    my $helpful =
      $self->find_or_new_related('helpfuls',
        {helpful => $args->{helpful}, user => $args->{user}->id});

    if ($helpful->in_storage) {
        $helpful->helpful($args->{helpful});
        $helpful->update;
        $rv = 2;
    }
    elsif ($helpful->insert) {
        $rv = 1;
    }

    if ($rv > 0) {
        $self->update_helpful_score;
    }

    return $rv;

}

sub helpful_total {
  my $self = shift;
  return $self->helpfuls->count;
}

sub helpful_yes {
  my $self = shift;
  return $self->helpfuls->count({ helpful => 1 });
}

sub checked_rating {
  my $self = shift;
  my $checked = {};
  for my $f (qw(rating_overall rating_1 rating_2 rating_3 rating_4)) {
    my $rating = $self->$f;
    $rating = 0 unless $rating and $rating =~ m/^[1-5]$/;
    $checked->{$f} = { $rating => "checked" };
  }
  $checked;
}

sub has_detail_ratings {
  my $self = shift;
  for my $i (1..4) {
    my $m = "rating_$i";
    return 1 if $self->$m;
  }
  return 0;
}

sub review_html {
  my $self = shift;
  convert_to_html( $self->review );
}

sub convert_to_html {
    my $str = shift;

    return "" unless defined $str and $str ne '';
    #$str =~ s@<.+?>@ @gs;

    $str = escape_html($str);

    $str
      =~ s!(https?://(.+?))([,.;-]+\s|\s|$)!"<a href=\"$1\" rel=\"nofollow\">"._shorten_text($2)."</a>$3"!egi;
    $str =~ s!\n\s*[\n\s]+!<br><br>!g;
    $str =~ s!\n!<br>\n!g;

    $str;
}

sub _shorten_text {
    my $linktext = shift;
    my $length   = shift || 40;
    return elide($linktext, $length);
}


1;
