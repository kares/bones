
require 'net/smtp'
require 'time'

module Bones::Plugins::Ann
  include ::Bones::Helpers
  extend self

  module Syntax
    def use_gmail( user = nil )
      email = ::Bones.config.ann.email
      user ||= ::Bones.config.email

      email.username  user
      email.server    'smtp.gmail.com'
      email.port      587
      email.authtype  :plain
    end
  end

  def initialize_ann
    ::Bones.config {
      desc 'Configuration for creating and mailing an announcement message.'
      ann {
        file  'announcement.txt', :desc => <<-__
          When announcing a release of your project the announcement text will
          be written to this file.
        __

        text  nil, :desc => 'Extra text to be appended to the announcement.'

        paragraphs  Array.new, :desc => <<-__
          Array of paragraphs from the README file to include in the
          announcement. The paragraphs are identified by their heading name in
          the README, but when listed here they can be given as lowercase or
          uppercase.
        __

        desc <<-__
          Configuration for e-mailing the announcement.

          A convenience method is provided for configuring Mr Bones to use
          gmail for sending project announcements. The project's e-mail
          address isused by default if a gmail username is not supplied.
          |
          |  use_gmail
          |  use_gmail 'username'
          |
          Use the latter form of the method is your gmail username is
          different then the project's e-mail address.
        __
        email {
          from  nil, :desc => <<-__
            The name to show on the 'from' line of the annoucement e-mail.
            This will default to the author name or the project e-mail if an
            author is not specified.
          __

          to  %w(ruby-talk@ruby-lang.org), :desc => 'An array of e-mail recipients.'

          server  'localhost', :desc => 'The server used to send the announcement e-mail.'

          port  25, :desc => 'The server port number to connect to.'

          domain  ENV['HOSTNAME'], :desc => <<-__
            The originating domain of the e-mail. This safely deafaults to the
            local hostname.
          __

          username  nil, :desc => 'The e-mail account name used to log into the e-mail server.'

          password  nil, :desc => 'The e-mail password used to log into the e-mail server.'

          authtype  :plain, :desc => <<-__
            The authentication type used by the e-mail server. This should be
            one of :plain, :login, or :cram_md5. See the documentation on the
            Net::SMTP class for more information.
          __

          enable_starttls_auto  true, :desc => <<-__
            When set to true, detects if STARTTLS is enabled in your SMTP server
            and starts to use it. It works only on Ruby >= 1.8.7 and Ruby >= 1.9.
          __
        }
      }
    }

    have?(:ann) { true }
  end

  def post_load
    config = ::Bones.config

    config.exclude << "^#{Regexp.escape(config.ann.file)}$"
    config.ann.email.from     ||= Array(config.authors).first || config.email
    config.ann.email.username ||= config.email
    config.ann.email.domain   ||= 'localhost'
  end

  def define_tasks
    config = ::Bones.config
    namespace :ann do

      # A prerequisites task that all other tasks depend upon
      task :prereqs

      file config.ann.file do
        ann = config.ann
        puts "Generating #{ann.file}"
        File.open(ann.file,'w') do |fd|
          fd.puts("#{config.name} version #{config.version}")
          fd.puts("    by #{Array(config.authors).first}") if config.authors
          fd.puts("    #{config.url}") if config.url.valid?
          fd.puts("    (the \"#{config.release_name}\" release)") if config.release_name
          fd.puts
          fd.puts("== DESCRIPTION")
          fd.puts
          fd.puts(config.description)
          fd.puts
          fd.puts(config.changes.sub(%r/^.*$/, '== CHANGES'))
          fd.puts
          ann.paragraphs.each do |p|
            fd.puts "== #{p.upcase}"
            fd.puts
            fd.puts paragraphs_of(config.readme_file, p).join("\n\n")
            fd.puts
          end
          fd.puts ann.text if ann.text
        end
      end

      desc "Create an announcement file"
      task :announcement => ['ann:prereqs', config.ann.file]

      desc "Send an email announcement"
      task :email => ['ann:prereqs', config.ann.file] do
        ann = config.ann
        email = config.ann.email

        from = email.from
        to   = Array(email.to)

        ### build a mail header for RFC 822
        rfc822msg =  "From: #{from}\n"
        rfc822msg << "To: #{to.join(',')}\n"
        rfc822msg << "Subject: [ANN] #{config.name} #{config.version}"
        rfc822msg << " (#{config.release_name})" if config.release_name
        rfc822msg << "\n"
        rfc822msg << "Date: #{Time.new.rfc822}\n"
        rfc822msg << "Message-Id: "
        rfc822msg << "<#{"%.8f" % Time.now.to_f}@#{email.domain}>\n\n"
        rfc822msg << File.read(ann.file)

        params = [:domain, :username, :password, :authtype].map { |key| email[key] }
        if params[2].nil?
          STDOUT.write "Please enter your e-mail password (#{params[1]}): "
          params[2] = STDIN.gets.chomp
        end

        ### send email
        smtp = Net::SMTP.new(email[:server], email[:port])
        smtp.enable_starttls_auto if email[:enable_starttls_auto] and smtp.respond_to?(:enable_starttls_auto)
        smtp.start(*params) { |_smtp_|
          _smtp_.sendmail(rfc822msg, from, to)
        }
      end
    end  # namespace :ann

    desc 'Alias to ann:announcement'
    task :ann => 'ann:announcement'

    CLOBBER << config.ann.file
  end

end  # module Bones::Plugins::Ann

# EOF
