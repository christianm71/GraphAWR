package Attributes;

# ========================================================================
sub new {
  my ($class) = @_;

  my $self = {
    attribute_list => {}
  };

  bless $self, $class;

  return $self;
}

# ========================================================================
sub set {
  my ($self, %args)=@_;

  foreach my $key (keys %args) {
    $self->{attribute_list}->{$key}=$args{$key};
  }
}

# ========================================================================
sub get {
  my ($self, $key)=@_;

  return $self->{attribute_list}->{$key};
}

# ========================================================================
sub unset {
  my ($self, $key)=@_;

  my $attribute_list=$self->{attribute_list};
  delete $attribute_list->{$key};
}

# ========================================================================
sub all_keys {
  my ($self)=@_;

  my $attribute_list=$self->{attribute_list};

  return (sort keys %{$attribute_list});
}

# ========================================================================
sub generate_code {
  my ($self, %args)=@_;

  my $default_attributes=$args{default_attributes} || 0;  # objet Attributes
  my $margin=$args{margin} || 0;

  my $str="";

  # ----- les keys definies dans cet objet -----
  foreach my $key ($self->all_keys()) {
    my $value=$self->get($key);

    if ($value=~m/^\d+$/) {
      $str.=sprintf("\n%s: %s,", $key, $value);
    }
    else {
      $str.=sprintf("\n%s: \"%s\",", $key, $value);
    }
  }

  # ----- les keys definies par defaut (sauf celles d'au-dessus) -----
  if ($default_attributes) {
    foreach my $key ($default_attributes->all_keys()) {
      my $value=$self->get($key);
      if (! defined($value)) {
        $str.=sprintf("\n%s: \"%s\",", $key, $default_attributes->get($key));
      }
    }
  }

  $str=~s/\n//;
  $str=~s/,$//;

  $margin=" " x $margin;
  $str=~s/\n/\n$margin/g;

  return "$margin$str";
}

1;
