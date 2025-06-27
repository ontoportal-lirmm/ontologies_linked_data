module LinkedData
  module Utils
    class Notifier
      def self.notify(options = {})
        return unless LinkedData.settings.enable_notifications

        email_options = {
          'sender' => options[:sender],
          'recipients' => options[:recipients],
          'subject' => options[:subject],
          'body' => options[:body]
        }

        # Queue the email job
        LinkedData::Jobs::EmailNotificationJob.perform_async(email_options)
      end

      def self.notify_support_grouped(subject, body)
        notify_mails_grouped subject, body, support_mails
      end

      def self.notify_subscribed_separately(subject, body, ontology, notification_type)
        mails = subscribed_users_mails(ontology, notification_type)
        notify_mails_separately subject, body, mails
      end

      def self.notify_administrators_grouped(subject, body, ontology)
        notify_support_grouped subject, body
      end

      def self.notify_mails_separately(subject, body, mails)
        mails.each do |mail|
          notify_mails_grouped subject, body, mail
        end
      end

      def self.notify_mails_grouped(subject, body, mail)
        options = {
          subject: subject,
          body: body,
          recipients: mail
        }
        notify(options)
      end

      def self.notify_support(subject, body)
        notify_mails_grouped subject, body, support_mails
      end

      def self.admin_mails(ontology)
        ontology.bring :administeredBy if ontology.bring? :administeredBy
        recipients = []
        ontology.administeredBy.each do |user|
          user.bring(:email) if user.bring?(:email)
          recipients << user.email
        end
        recipients
      end

      def self.support_mails

        if !LinkedData.settings.admin_emails.nil? &&
          LinkedData.settings.admin_emails.kind_of?(Array)
          return LinkedData.settings.admin_emails
        end
        []
      end

      def self.subscribed_users_mails(ontology, notification_type)
        emails = []
        ontology.bring(:subscriptions) if ontology.bring?(:subscriptions)
        ontology.subscriptions.each do |subscription|

          subscription.bring(:notification_type) if subscription.bring?(:notification_type)
          subscription.notification_type.bring(:type) if subscription.notification_type.bring?(:notification_type)

          unless subscription.notification_type.type.eql?(notification_type.to_s.upcase) ||
            subscription.notification_type.type.eql?('ALL')
            next
          end

          subscription.bring(:user) if subscription.bring?(:user)
          subscription.user.each do |user|
            user.bring(:email) if user.bring?(:email)
            emails << user.email
          end
        end
        emails
      end

      def self.mail_options
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
