# RokuUI.pm version 0.1
#
# Copyright Michael Polymenakos 2007 mpoly@panix.com
#
# Released under the GPL. http://www.gnu.org/licenses/gpl.txt
#


use strict;
use Net::Telnet;

package RokuUI;

sub RokuDisplay {

  sub new {
    my $class = shift;
    my $self = {@_};    
    bless ($self, $class);
    return $self;
  }

  sub DESTROY { 
    my $self = shift;
    if (defined($self->{connection})) {     
      $self->close()
    }
  }
  
  sub open() {
    my $self  = shift;

    $self->{port} = 4444 if !$self->{port};

    $self->{connection} = Net::Telnet->new(
       Port       => $self->{port},
       Prompt     => '/SoundBridge> $/',
       Timeout    => 15,
       Errmode    => 'return'       
    );

    if ($self->{connection}->open($self->{host})) { 
      return 1;
    } else { 
      return 0;
    }
  }

  sub close() {
    my $self = shift;
    if(defined($self->{connection})) { 
       $self->{connection}->cmd("sketch -c clear");
       $self->{connection}->cmd("sketch -c exit");
       $self->{connection}->cmd("irman off");
       $self->{connection}->cmd("exit");
       $self->{connection}->close();
    }
  }

  sub msg() {

    #
    # text          - default none - can be ommited to just set font and encoding
    # x,y  location - default 0,0
    # font          - 
    # encoding      - default is latin1
    # duration      - in seconds, default 5. 0 means exit and leave text displayed
    # mode          - default 'text'. Any abbreviation of "marquee" results in a marquee
    # keygrab       - determines what happens when a user hits a key
    # keygrab=0     - (default) the routine is interrupted, and the keypress is passed on to the roku
    # keygrab=1     - the routine is interrupted, and the keypress is returned to the caller
    # keygrab=2     - the routine is not interrupted, and the keypress is discarded
    # clear         - 0/1 force the display to clear first (default 0)
    #

    my $self = shift;
  
    return 0 if !($self->{connection});
    
    my %args = @_;
    
    my $x = $args{'x'} || 0;
    my $y = $args{'y'} || 0;
    my $text = $args{'text'} || "";
    my $font = $args{'font'} || $self->{'font'};
    my $encoding =  $args{'encoding'} || $self->{'encoding'};
    my $keygrab  =  $args{'keygrab'};
    my $clear    =  $args{'clear'}    || 0;
    my $duration =  $args{'duration'};

    if ($keygrab eq '') { # 0 is a valid value
      $keygrab = 1;
    }
    
    if ($duration eq '') { # 0 is a valid value
      $duration = $self->{'duration'} || 5 ;
    }
    
    my $marquee  =  $args{'mode'} =~ /^m(a(r(q(u(ee?)?)?)?)?)?$/i ? 1 : 0;

    if ($encoding) { 
      $self->{connection}->cmd("sketch -c encoding $encoding");
    }
    
    if ($font) {
      $self->{connection}->cmd("sketch -c font $font");
    }   

    return 1 if !$text;    
    
    # preemptive strike - apparently text after marquee is appended to the marquee
    if ($self->{marquee} && (!$marquee)) { 
      $self->{marquee} = 0;
      $self->{connection}->cmd("sketch -c marquee -stop");
      $self->{connection}->cmd("sketch -c clear");
    } elsif ($clear) { 
      $self->{connection}->cmd("sketch -c clear");
    }

    #Escape quotes 
    $text =~ s/"/\\"/;

    if ($marquee) { 
      $self->{marquee} = 1;      
      $self->{connection}->cmd("sketch -c marquee -start \"$text\"");
    } else {       
      $self->{connection}->cmd("sketch -c text $x $y \"$text\"");
    }
      
    if ($duration) { 

      if ($keygrab == 2) { 
        sleep($duration);
        #$self->{connection}->cmd("sketch -c exit");
        return "TIMEOUT";  # for consistency...
      }
        
      $self->{connection}->cmd("irman intercept");

      my ($p, $m) = $self->{connection}->waitfor(Match    => '/irman: .*/',
                                                 Timeout  => $duration);

      $self->{connection}->cmd("irman off");

      if ($m) { 
        $m =~ s/^irman: //;
        if (!$keygrab) { 
          $self->{connection}->cmd("sketch -c exit");        
          $self->{connection}->cmd("irman dispatch $m");  
        }
        return $m;
      } else {  
        return "TIMEOUT";         
      }
    } else {
      return 1;
    }
 }
  
 sub ison() {
    my $self = shift;
    return 0 if !($self->{connection});

    my @ps = $self->{connection}->cmd("ps");

    for my $ps (@ps) { 
      return 0 if $ps =~ / StandbyApp\n/;
    }
    return 1;
  }
  
  sub cmd() {
    my $self = shift;
    return 0 if !($self->{connection});
    return $self->{connection}->cmd(shift);
  }
  
  sub clear() {
    my $self = shift;
    return 0 if !($self->{connection});
    
    if ($self->{inmarquis}) { 
      $self->{inmarquis} = 0;
      $self->{connection}->cmd("sketch -c marquee -stop");
    }
    
    $self->{connection}->cmd("sketch -c clear");    
    
    return 1
  }  
} 

;1;

