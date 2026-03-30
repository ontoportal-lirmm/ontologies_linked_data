module LinkedData
  module Jobs
    class EmailNotificationJob < LinkedData::Jobs::Base
      sidekiq_options queue: 'mailers'
    
      def perform(options = {})
        return unless LinkedData.settings.enable_notifications
    
        headers = { 'Content-Type' => 'text/html' }
        sender = options['sender'] || LinkedData.settings.email_sender
        recipients = Array(options['recipients']).uniq
        raise ArgumentError, 'Recipient needs to be provided in options[:recipients]' if !recipients || recipients.empty?
    
        # By default we override all recipients to avoid
        # sending emails from testing environments.
        # Set `email_disable_override` in production
        # to send to the actual user.
        unless LinkedData.settings.email_disable_override
          headers['Overridden-Sender'] = recipients
          recipients = LinkedData.settings.email_override
        end
      
        Pony.mail({
                    to: recipients,
                    from: sender,
                    subject: options['subject'],
                    body: options['body'],
                    headers: headers,
                    via: :smtp,
                    enable_starttls_auto: LinkedData.settings.enable_starttls_auto,
                    via_options: mail_options
                  })
      end
    
      private
    
      def mail_options
        options = {
          address: LinkedData.settings.smtp_host,
          port: LinkedData.settings.smtp_port,
          domain: LinkedData.settings.smtp_domain # the HELO domain provided by the client to the server
        }
      
        if LinkedData.settings.smtp_auth_type && LinkedData.settings.smtp_auth_type != :none
          options.merge!({
                           user_name: LinkedData.settings.smtp_user,
                           password: LinkedData.settings.smtp_password,
                           authentication: LinkedData.settings.smtp_auth_type
                         })
        end
      
        options
      end
    end
  end
end