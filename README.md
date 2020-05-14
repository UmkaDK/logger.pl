logger.pl
=========

**Status:** ARCHIVED - Fully functional, but missing tests  
**Version:** 1.0.29  

*   [NAME](#NAME)
*   [SYNOPSIS](#SYNOPSIS)
*   [SIMPLE USAGE](#SIMPLE-USAGE)
*   [ADVANCED USAGE](#ADVANCED-USAGE)
*   [CONFIGURATION](#CONFIGURATION)
*   [LOCALISATION](#LOCALISATION)
*   [INTERFACE](#INTERFACE)
*   [SEE ALSO](#SEE-ALSO)
*   [DONATIONS](#DONATIONS)

## NAME

Umka::Logger - multi-channel logger for user messages

## SYNOPSIS

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

## SIMPLE USAGE

In it's simplest form, this module provides ability to output localised user messages to the default output logger (ie: Screen). All messages recorded by the module are subdivided into six basic channels: fatal, error, warn, info, debug and trace. Where each channel is designed for the following use:

        FATAL - Final output messages before termination of the module.
        ERROR - Non-terminal module errors, use in preference to croak.
         WARN - Low importance warnings issued by the script / module.
         INFO - General output messages, aka user interaction layer.
        DEBUG - General description of what is happening inside the package.
        TRACE - Detailed description of the subroutines involved.

Unlike many modules distributed by CPAN this module does not necessarily need to be initialise by invoking the new() subroutine. In fact, the module can be initialise simply by specifying a common message ID as part of the module inclusion into the parent script, for example:

        use Umka::Logger(__PACKAGE__);

Where __PACKAGE__ is the name of the current package at the compile time (or undefined if there is no current package). Thus, the above code would record a standard initialisation message to the INFO channel. Such message would also include current package name and the name of the invocation script.

By default, only information logged to the FATAL, ERROR, WARN & INFO channels is displayed, DEBUG and TRACE channels are ignored. This behaviour can be modified by supplying an optional reference to the configuration hash (see CONFIGURATION section for more info), for example:

        use Umka::Logger(__PACKAGE__, {'verbose' => 'DEBUG'});

Furthermore, output of all messages can be modified by passing a third optional parameter during module initialisation: a reference to the locale hash (see LOCALISATION section for more info):

        use Umka::Logger(__PACKAGE__, {'verbose' => 'DEBUG'},
            {'init_use' = > 'Invoker script %s, module loaded by %s'});

Simple invocation is designed for keeping track of the current package's usage pattern and figuring out what scripts and other packages rely on this module.

## ADVANCED USAGE

The more advanced usage of this module requires modifying the invoker script to initialise Message in a more conventional way, with use and new statements:

        use Umka::Logger;
        my $Msg = new Umka::Logger(__PACKAGE__);

Similarly, to the simple invocation of the module, new() function can take two optional parameters: config and locale. Both are defined by a hash reference and can reconfigure the module to behave in a highly customised way, for more information please see CONFIGURATION and LOCALISATION sections.

        use Umka::Logger(__PACKAGE__, {'verbose' => 'DEBUG'},
            {'init_use' = > 'Invoker script %s, module loaded by %s'});

Unlike simple interface, once the module is initialised, the user will be able to assign custom message to any of the channels using module's API. All, message assigned in such way will implisitly support localisation and be customisable by the user.

Advanced interface is geared primarily towards generating user interaction messages and as such we do not necessarily want to know when and who by Message package has been initialise. Therefore, package initialisation message is stored in the DEBUG channel, not INFO as it happens during the simple initialisation process.

## CONFIGURATION

Both a simple invocation through use() and advanced initialisation through new() statements support an optional configuration parameter which is used to partially or completely override the default configuration of the module. Thus, both of the following fragment of code modify Message verbosity level in an identical way:

        1\. use Umka::Logger(__PACKAGE__, {'verbose' => 'DEBUG'});

        2\. my $config = {'verbose' => 'DEBUG'};
           $Msg = new Umka::Logger(__PACKAGE__, $config);

The following configuration options are supported:

<dl>

<dt id="verbose">verbose</dt>

<dd>

This option controls the verbosity level of the reporting for the current module. Given six output channels (FATAL, ERROR, WARN, INFO, DEBUG, TRACE) it defines the top most channel messages from which we wish to display. Thus, if set to INFO (default) then messages to FATAL, ERROR, WARN and INFO are shown, while messages to DEBUG and TRACE are ignored.

</dd>

<dt id="logger">logger</dt>

<dd>

This option is used to identify all loggers which will be used to record messages from a particular module. It is quite versatile and can take be assigned either a string or a reference to an array or a hash as its value.

If a string or an array reference is supplied then this module assumes that the value contains either a single or a list of Log4perl output loggers. This loggers are passed directly to the required Log4perl module, and are used with their default values as part of log4perl.logger configuration string.

If a reference to a hash is supplied then it is assumed that we are using loggers with custom configuration in the format similar to Log4perl config. The only differences between our config format and Log4perl, are:

*   Unlike log4perl we define our appender name as a key of the config hash. (Obviously, the module is initialised by passing a reference of that hash to the import() or new() methods.)

*   Our custom 'appender' key corresponds directly to log4perl's appender value, and is defined in the identical format.

*   'log4perl.appender.[appenderName]' prefix string is omitted from the beginning of all configuration keys.

The following is an example of configuring log4perl Screen appender using our customised format:

        my $config = {
            'Screen'    => {
                'appender' => 'Log::Log4perl::Appender::Screen',
                'stderr' => 0,
                'layout' => 'PatternLayout',
                'layout.ConversionPattern' => '%d [%P] %m{chomp} %n',
            },
        };

See Log::Log4perl::Config for further examples and explanation of all available appenders and their configuration options.

</dd>

<dt id="log_method_use">log_method_use</dt>

<dt id="log_method_new">log_method_new</dt>

<dd>

This two functions define a method / subroutine called to record an initialisation message for when the package is loaded via either use() or new() method. By default, log_method_use is set to 'info', which logs init message to the INFO channel; and log_method_new is set to 'debug', which logs init message to the DEBUG channel.

</dd>

</dl>

## LOCALISATION

All messages output by the module's interface / API calls inherently support localisation and customisation. However, for any string to be localised, we need to tell Messages package what to translate an incoming string to. This is done by supplying an optional third parameter (locale) during module initialisation, for example:

        use Umka::Logger(__PACKAGE__, undef, \%locale);

Where 'locale' is a reference to a hash that defines translation key-value pairs. For example, default package locale is as follows:

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

All strings defined as keys are translated into their corresponding values. If a string does not exists with in the locale hash then it is output with out any modifications.

## INTERFACE

When Message module is initialised using the advanced interface it exposes a number of user functions, most of these are used to record custom messages or to convert user input into a preconfigured, pre-formatted string. See LOCALISATION section for more information.

The following is a full list of all available functions.

<dl>

<dt id="locale-str-arg1-arg2-arg3">locale($str, [$arg1, $arg2, $arg3...])</dt>

<dd>

This function is used to convert a string key into a properly formatted string value. It checks if supplied string matches one of the existing keys in the global locale hash. If it does, then the string is substituted for the locale value, if it doesn't then the string is used as is.

Before being returned to the user or logged using one of the output appenders, the string is populated with the optional list of supplied arguments using PERL internal sprintf function. After that, the message is reformatted again, as per logger's output string format.

</dd>

<dt id="fatal-str-arg1-arg2-arg3">fatal($str, [$arg1, $arg2, $arg3...])</dt>

<dt id="error-str-arg1-arg2-arg3">error($str, [$arg1, $arg2, $arg3...])</dt>

<dt id="warn-str-arg1-arg2-arg3">warn($str, [$arg1, $arg2, $arg3...])</dt>

<dt id="info-str-arg1-arg2-arg3">info($str, [$arg1, $arg2, $arg3...])</dt>

<dt id="debug-str-arg1-arg2-arg3">debug($str, [$arg1, $arg2, $arg3...])</dt>

<dt id="trace-str-arg1-arg2-arg3">trace($str, [$arg1, $arg2, $arg3...])</dt>

<dd>

This functions work in a similar way to the locale() described above and allow the user to log a message to one of the predefined log channels: FATAL, ERROR, WARN, INFO, DEBUG, and TRACE (in descending priority). Your configured logging level has to at least match the priority of the logging message. Also the message will be further formatted as per logger's output string format.

</dd>

</dl>

## SEE ALSO

English, Carp, POSIX, Log::Log4perl, Log::Dispatch.
