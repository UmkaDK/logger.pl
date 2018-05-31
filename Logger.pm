#!/usr/bin/perl

$VERSION = '1.0.0 $Revision: 29 $';
$VERSION =~ s/\$R(\w+):(.+)\$/r$1$2/g;

package Umka::Logger;

use 5.8.1;
use strict;
use warnings;

# Declare required modules
use English;
use Carp;
use POSIX;
use Log::Log4perl;
use Log::Dispatch;
use Data::Dumper;

# Initialise private variables
our $config = {
    'verbose'           => 'INFO',
    'logger'            => 'Screen',
    'log_method_use'    => 'info',
    'log_method_new'    => 'debug',
};

# Initialise localised message stack
our $locale = {
    # User defined custom strings
    'init_use'          => '%s -> %s -> use '.__PACKAGE__.'()',
    'init_new'          => '%s -> %s -> new '.__PACKAGE__.'()',

    # Error reporting and logging strings
    'invalid_init'      => 'Ignoring, messages already initialised.',
    'invalid_arg'       => 'Invalid %s: value is not a HASH REF.',
    'invalid_verbose'   => 'Invalid log level: %s',
    'invalid_logger'    => 'Invalid logger: %s',
};

# Configure output channels
# NOTE: Do not edit this unless you are familiar with configuring Log4perl!
#       'appender' is the only custom key, the rest of the keys are standard
#       log4perl keys excluding the 'log4perl.appender.@logger@' prefix.
our $output = {
    'levels'    => ['FATAL', 'ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE'],
    'logger'    => {
        'Screen'    => {
            'appender'                  => 'Log::Log4perl::Appender::Screen',
            'stderr'                    => 0,
            'layout'                    => 'PatternLayout',
            'layout.ConversionPattern'  => '%m{chomp} %n',
        },

        'File'      => {
            'appender'                  => 'Log::Log4perl::Appender::File',
            'filename'                  => '/dev/null',
            'layout'                    => 'PatternLayout',
            'layout.ConversionPattern'  => '%d [PID %P, %p] %m{chomp} %n',
        },

        'Email'     => {
            'appender'                  => 'Log::Dispatch::Email::MailSend',
            'from'                      => '',
            'to'                        => '',
            'subject'                   => __PACKAGE__,
            'layout'                    => 'PatternLayout',
            'layout.ConversionPattern'  => '%d [PID %P, %p] %m{chomp} %n',
        },

        'Syslog'    => {
            'appender'                  => 'Log::Dispatch::Syslog',
            'ident'                     => __PACKAGE__,
            'layout'                    => 'PatternLayout',
            'layout.ConversionPattern'  => '[PID %P, %p] %m{chomp} %n',
        },
    },
};

# Initialise global containers
our ($Log);

##
#
# Importer - initialised upon "use"
#
sub import(;$$$) {
    # Initialise local class
    my $class = shift(@_);
    my $this = {};
    bless($this, $class);

    # Define module's constructor arguments
    my ($id, $new_config, $new_locale)  = @_;

    # Only proceed if a tracking id has been supplied
    return 1 if (! $id);

    # Initialise messages object
    if ($this->init($new_config, $new_locale)) {
        my $method = $config->{'log_method_use'};
        $this->$method('init_use', $0, $id);
    }

    return $this;
}

##
#
# Constructor - initialised upon "new"
#
sub new($;$$) {
    # Initialise local class
    my $class = shift(@_);
    my $this = {};
    bless($this, $class);

    # Define module's constructor arguments
    my ($id, $new_config, $new_locale)  = @_;

    # Initialise messages object
    if ($this->init($new_config, $new_locale)) {
        my $method = $config->{'log_method_new'};
        $this->$method('init_new', $0, $id);
    }

    return $this;
}

##
#
# Common initialisation routines
#
sub init(;$$) {
    my ($this, $new_config, $new_locale) = @_;

    # Ensure that new config is a refference to a hash
    if ($new_config) {
        # Croak unless supplied config is a refference to a hash
        if (ref($config) ne 'HASH') {
            croak($this->locale('invalid_arg', 'config'));
        }

        # Update existing config to include new values
        $config = {(%{$config}, %{$new_config})};
    }

    # Ensure that new locale is a refference to a hash
    if ($new_locale) {
        # Croak unless supplied locale is a refference to a hash
        if (ref($locale) ne 'HASH') {
            croak($this->locale('invalid_arg', 'locale'));
        }

        # Update existing locale to include new values
        $locale = {(%{$locale}, %{$new_locale})};
    }

    # Complain if verbose value is uninitialized
    croak($this->locale('invalid_verbose', 'uninitialized or empty'))
        unless (exists($config->{'verbose'}) and $config->{'verbose'});

    # Detect numeric verbose values
    if ($config->{'verbose'} =~ m/^\d+$/) {
        $config->{'verbose'} = $config->{'verbose'} <= $#{$output->{'levels'}}
            ? $output->{'levels'}->[$config->{'verbose'}]
            : $output->{'levels'}->[$#{$output->{'levels'}}];
    }

    # Process literal verbose values
    else {
        # Make sure that configured log level is in upper case
        $config->{'verbose'} = uc($config->{'verbose'});

        # Complain if unknown verbose value has been requested
        croak($this->locale('invalid_verbose', $config->{'verbose'}))
            unless (grep(/^$config->{'verbose'}$/, @{$output->{'levels'}}));
    }

    # Validate logger if one is defined
    if (exists($config->{'logger'}) and $config->{'logger'}) {
        # Logger is a hash ref - one or many loggers, custom configs
        if (ref($config->{'logger'}) eq 'HASH') {
            foreach my $key (keys(%{$config->{'logger'}})) {
                $output->{'logger'}->{$key} =
                    exists($output->{'logger'}->{$key})
                        ? {(%{$output->{'logger'}->{$key}},
                            %{$config->{'logger'}->{$key}})}
                        : %{$config->{'logger'}->{$key}};
            }

            # Convert configured logger value into log4perl format
            $config->{'logger'} = join(', ', keys(%{$config->{'logger'}}));
        }

        # Logger is an array ref - convert to a log4perl format
        elsif (ref($config->{'logger'}) eq 'ARRAY') {
            $config->{'logger'} = join(', ', @{$config->{'logger'}});
        }

        # Compare logger string to log4perl expected format
        elsif ($config->{'logger'} !~ m/^\s*\w+(,\s*\w+)*\s*$/s) {
            croak($this->locale('invalid_logger', 'unsupported format'));
        }
    }

    # Complain if logger value is missing
    else {
        croak($this->locale('invalid_logger', 'uninitialized or empty'))
    }

    # Initialise log4perl configuration
    my $log_config = {
        'log4perl.logger' => "$config->{'verbose'}, $config->{'logger'}"
    };

    # Process all requested loggers (one by one)
    foreach my $logger (split(/,\s*/, $config->{'logger'})) {
        # Pre-format logger name
        $logger =~ s/^\s+|\s+$//sg;

        # Complain if unknown logger has been requested
        if (! grep(/^$logger$/, keys(%{$output->{'logger'}}))) {
            croak($this->locale('invalid_logger', $logger));
        }

        # Define variables common to this logger
        my $prefix = "log4perl.appender.${logger}";
        $log_config->{$prefix} = $output->{'logger'}->{$logger}->{'appender'};

        # Build log configuration for the current logger
        foreach my $config (keys(%{$output->{'logger'}->{$logger}})) {
            next if ( $config eq 'appender' );
            $log_config->{"${prefix}.${config}"} =
                $output->{'logger'}->{$logger}->{$config};
        }
    }

    # Initialise module logging and reporting mechanism
    Log::Log4perl->init($log_config)
        or croak($this->locale('invalid_config', $log_config));
    $Log = Log::Log4perl->get_logger();

    return 1;
}

##
#
# Localised print and logging methods
#
sub locale($;@) {
    my ($this, $text, @args) = @_;
    chomp $text;
    $text = $locale->{$text} if (exists($locale->{$text}));
    return sprintf($text, @args);
}

sub fatal($;@) {
    my ($this, $text, @args) = @_;
    return $Log->fatal($this->locale($text, @args));
}

sub error($;@) {
    my ($this, $text, @args) = @_;
    return $Log->error($this->locale($text, @args));
}

sub warn($;@) {
    my ($this, $text, @args) = @_;
    return $Log->warn($this->locale($text, @args));
}

sub info($;@) {
    my ($this, $text, @args) = @_;
    return $Log->info($this->locale($text, @args));
}

sub debug($;@) {
    my ($this, $text, @args) = @_;
    return $Log->debug($this->locale($text, @args));
}

sub trace($;@) {
    my ($this, $text, @args) = @_;
    return $Log->trace($this->locale($text, @args));
}

1;

__END__

=head1 NAME

Umka::Logger - multi-channel output for user messages

=head1 SYNOPSIS

Simple usage:

    use Umka::Logger(__PACKAGE__, $config, $locale);

Advanced usage:

    use Umka::Logger;
    $Msg = new Umka::Logger(__PACKAGE__, $config, $locale);

    my $message = $Msg->locale('localised message');
    print $message;

    $Msg->fatal('%s has been terminated', $0);
    $Msg->error('%s reported an error', $0);
    $Msg->warn('%s reported a warning', $0);
    $Msg->info('%s generated a message', $0);
    $Msg->debug('%s recorded debug', $0);
    $Msg->trace('%s has left a trace', $0);

=head1 SIMPLE USAGE

In it's simplest form, this module provides ability to output localised user
messages to the default output logger (ie: Screen). All messages recorded by
the module are subdivided into six basic channels: fatal, error, warn, info,
debug and trace. Where each channel is designed for the following use:

    FATAL - Final output messages before termination of the module.
    ERROR - Non-terminal module errors, use in preference to croak.
     WARN - Low importance warnings issued by the script / module.
     INFO - General output messages, aka user interaction layer.
    DEBUG - General description of what is happening inside the package.
    TRACE - Detailed description of the subroutines involved.

Unlike many modules distributed by CPAN this module does not necessarily need
to be initialise by invoking the new() subroutine. In fact, the module can be
initialise simply by specifying a common message ID as part of the module
inclusion into the parent script, for example:

    use Umka::Logger(__PACKAGE__);

Where __PACKAGE__ is the name of the current package at the compile time (or
undefined if there is no current package). Thus, the above code would record a
standard initialisation message to the INFO channel. Such message would also
include current package name and the name of the invocation script.

By default, only information logged to the FATAL, ERROR, WARN & INFO channels
is displayed, DEBUG and TRACE channels are ignored. This behaviour can be
modified by supplying an optional reference to the configuration hash (see
CONFIGURATION section for more info), for example:

    use Umka::Logger(__PACKAGE__, {'verbose' => 'DEBUG'});

Furthermore, output of all messages can be modified by passing a third
optional parameter during module initialisation: a reference to the locale
hash (see LOCALISATION section for more info):

    use Umka::Logger(__PACKAGE__, {'verbose' => 'DEBUG'},
        {'init_use' = > 'Invoker script %s, module loaded by %s'});

Simple invocation is designed for keeping track of the current package's usage
pattern and figuring out what scripts and other packages rely on this module.

=head1 ADVANCED USAGE

The more advanced usage of this module requires modifying the invoker script to
initialise Message in a more conventional way, with use and new statements:

    use Umka::Logger;
    my $Msg = new Umka::Logger(__PACKAGE__);

Similarly, to the simple invocation of the module, new() function can take two
optional parameters: config and locale. Both are defined by a hash reference
and can reconfigure the module to behave in a highly customised way, for more
information please see CONFIGURATION and LOCALISATION sections.

    use Umka::Logger(__PACKAGE__, {'verbose' => 'DEBUG'},
        {'init_use' = > 'Invoker script %s, module loaded by %s'});

Unlike simple interface, once the module is initialised, the user will be able
to assign custom message to any of the channels using module's API. All,
message assigned in such way will implisitly support localisation and be
customisable by the user.

Advanced interface is geared primarily towards generating user interaction
messages and as such we do not necessarily want to know when and who by
Message package has been initialise. Therefore, package initialisation message
is stored in the DEBUG channel, not INFO as it happens during the simple
initialisation process.

=head1 CONFIGURATION

Both a simple invocation through use() and advanced initialisation through
new() statements support an optional configuration parameter which is used to
partially or completely override the default configuration of the module.
Thus, both of the following fragment of code modify Message verbosity level in
an identical way:

    1. use Umka::Logger(__PACKAGE__, {'verbose' => 'DEBUG'});

    2. my $config = {'verbose' => 'DEBUG'};
       $Msg = new Umka::Logger(__PACKAGE__, $config);

The following configuration options are supported:

=over

=item verbose

This option controls the verbosity level of the reporting for the current
module. Given six output channels (FATAL, ERROR, WARN, INFO, DEBUG, TRACE) it
defines the top most channel messages from which we wish to display. Thus, if
set to INFO (default) then messages to FATAL, ERROR, WARN and INFO are shown,
while messages to DEBUG and TRACE are ignored.

=item logger

This option is used to identify all loggers which will be used to record
messages from a particular module. It is quite versatile and can take be
assigned either a string or a reference to an array or a hash as its value.

If a string or an array reference is supplied then this module assumes that
the value contains either a single or a list of Log4perl output loggers. This
loggers are passed directly to the required Log4perl module, and are used with
their default values as part of log4perl.logger configuration string.

If a reference to a hash is supplied then it is assumed that we are using
loggers with custom configuration in the format similar to Log4perl config.
The only differences between our config format and Log4perl, are:

=over

=item *

Unlike log4perl we define our appender name as a key of the config hash.
(Obviously, the module is initialised by passing a reference of that hash to
the import() or new() methods.)

=item *

Our custom 'appender' key corresponds directly to log4perl's appender value,
and is defined in the identical format.

=item *

'log4perl.appender.[appenderName]' prefix string is omitted from the beginning
of all configuration keys.

=back

The following is an example of configuring log4perl Screen appender using our
customised format:

    my $config = {
        'Screen'    => {
            'appender' => 'Log::Log4perl::Appender::Screen',
            'stderr' => 0,
            'layout' => 'PatternLayout',
            'layout.ConversionPattern' => '%d [%P] %m{chomp} %n',
        },
    };

See Log::Log4perl::Config for further examples and explanation of all
available appenders and their configuration options.

=item log_method_use

=item log_method_new

This two functions define a method / subroutine called to record an
initialisation message for when the package is loaded via either use() or
new() method. By default, log_method_use is set to 'info', which logs init
message to the INFO channel; and log_method_new is set to 'debug', which logs
init message to the DEBUG channel.

=back

=head1 LOCALISATION

All messages output by the module's interface / API calls inherently support
localisation and customisation. However, for any string to be localised, we
need to tell Messages package what to translate an incoming string to. This
is done by supplying an optional third parameter (locale) during module
initialisation, for example:

    use Umka::Logger(__PACKAGE__, undef, \%locale);

Where 'locale' is a reference to a hash that defines translation key-value
pairs. For example, default package locale is as follows:

    # Initialise localised message stack
    our $locale = {
        # User defined custom strings
        'init_use'          => '%s -> %s -> use '.__PACKAGE__.'()',
        'init_new'          => '%s -> %s -> new '.__PACKAGE__.'()',

        # Error reporting and logging strings
        'invalid_init'      => 'Ignoring, messages already initialised.',
        'invalid_arg'       => 'Invalid %s: value is not a HASH REF.',
        'invalid_verbose'   => 'Invalid log level: %s',
        'invalid_logger'    => 'Invalid logger: %s',
    };

All strings defined as keys are translated into their corresponding values. If
a string does not exists with in the locale hash then it is output with out
any modifications.

=head1 INTERFACE

When Message module is initialised using the advanced interface it exposes
a number of user functions, most of these are used to record custom messages
or to convert user input into a preconfigured, pre-formatted string. See
LOCALISATION section for more information.

The following is a full list of all available functions.

=over

=item locale($str, [$arg1, $arg2, $arg3...])

This function is used to convert a string key into a properly formatted string
value. It checks if supplied string matches one of the existing keys in the
global locale hash. If it does, then the string is substituted for the locale
value, if it doesn't then the string is used as is.

Before being returned to the user or logged using one of the output appenders,
the string is populated with the optional list of supplied arguments using
PERL internal sprintf function. After that, the message is reformatted again,
as per logger's output string format.

=item fatal($str, [$arg1, $arg2, $arg3...])

=item error($str, [$arg1, $arg2, $arg3...])

=item warn($str, [$arg1, $arg2, $arg3...])

=item info($str, [$arg1, $arg2, $arg3...])

=item debug($str, [$arg1, $arg2, $arg3...])

=item trace($str, [$arg1, $arg2, $arg3...])

This functions work in a similar way to the locale() described above and allow
the user to log a message to one of the predefined log channels: FATAL, ERROR,
WARN, INFO, DEBUG, and TRACE (in descending priority). Your configured logging
level has to at least match the priority of the logging message. Also the
message will be further formatted as per logger's output string format.

=back

=head1 SEE ALSO

English, Carp, POSIX, Log::Log4perl, Log::Dispatch.

=cut

    vim: set ts=4 sw=4 tw=78:
