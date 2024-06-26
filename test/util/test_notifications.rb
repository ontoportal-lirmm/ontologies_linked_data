require_relative "../test_case"
require "email_spec"
require "logger"

class TestNotifications < LinkedData::TestCase
  include EmailSpec::Helpers

  def self.before_suite
    @@notifications_enabled = LinkedData.settings.enable_notifications
    @@disable_override = LinkedData.settings.email_disable_override
    @@old_support_mails = LinkedData.settings.admin_emails
    if @@old_support_mails.nil? || @@old_support_mails.empty?
      LinkedData.settings.admin_emails  = ["ontoportal-support@mail.com"]
    end
    LinkedData.settings.email_disable_override = true
    LinkedData.settings.enable_notifications = true
    @@ui_name = LinkedData.settings.ui_name
    @@support_mails = LinkedData.settings.admin_emails
    @@ont = LinkedData::SampleData::Ontology.create_ontologies_and_submissions(ont_count: 1, submission_count: 1)[2].first
    @@ont.bring_remaining
    @@user = @@ont.administeredBy.first
    @@user.bring_remaining

    @@subscription = self.new("before_suite")._subscription(@@ont)

    @@user2 = LinkedData::Models::User.new(username: "tim2", email: "tim2@example.org", password: "password").save
    @@user2.bring_remaining
    @@user2.subscription = [@@subscription]
    @@user2.save
  end

  def self.after_suite
    LinkedData.settings.enable_notifications = @@notifications_enabled
    LinkedData.settings.email_disable_override = @@disable_override
    LinkedData.settings.admin_emails = @@old_support_mails
    @@ont.delete if defined?(@@ont)
    @@subscription.delete if defined?(@@subscription)
    @@user.delete if defined?(@@user)
  end

  def setup
    LinkedData.settings.email_disable_override = true
  end

  def _subscription(ont)
    subscription = LinkedData::Models::Users::Subscription.new
    subscription.ontology = ont
    subscription.notification_type = LinkedData::Models::Users::NotificationType.find("ALL").first
    subscription.save
  end

  def test_send_notification
    recipients = ["test@example.org"]
    subject = "Test subject"
    body = "My test body"

    # Email recipient address will be overridden
    LinkedData.settings.email_disable_override = false
    LinkedData::Utils::Notifier.notify(recipients: recipients)
    assert_equal [LinkedData.settings.email_override], last_email_sent.to

    # Disable override
    LinkedData.settings.email_disable_override = true
    LinkedData::Utils::Notifier.notify({
                                         recipients: recipients,
                                         subject: subject,
                                         body: body
                                       })
    assert_equal recipients, last_email_sent.to
    assert_equal [LinkedData.settings.email_sender], last_email_sent.from
    assert_equal last_email_sent.body.raw_source, body
    assert_equal last_email_sent.subject, subject
  end

  def test_new_user_notification
    @@user2.save(send_notifications: true)

    assert_equal LinkedData.settings.admin_emails, last_email_sent.to
    assert last_email_sent.body.raw_source['A new user have been created']
  end

  def test_new_note_notification
    begin
      subject = "Test note subject"
      body = "Test note body"
    note = LinkedData::Models::Note.new
    note.creator = @@user
    note.subject = subject
    note.body = body
    note.relatedOntology = [@@ont]
    note.save
    assert last_email_sent.subject.include?("[#{@@ui_name} Notes]")
    last_emails = all_emails[-2..]
    assert_equal [@@user.email, LinkedData.settings.admin_emails].flatten.sort, last_emails.last.to.sort
      assert_equal [@@user2.email].sort, last_emails.first.to.sort
    ensure
      note.delete if note
    end
  end

  def test_processing_complete_notification
    begin
      options = { ont_count: 1, submission_count: 1, acronym: "NOTIFY" }
      ont = LinkedData::SampleData::Ontology.create_ontologies_and_submissions(options)[2].first
      subscription = _subscription(ont)
      @@user.subscription = @@user.subscription.dup << subscription
    @@user.save
      ont.latest_submission(status: :any).process_submission(Logger.new(TestLogFile.new), process_rdf: true,
                                                             extract_metadata: false, generate_missing_labels: false)
      subscription.bring :user
      admin_mails =  LinkedData::Utils::Notifier.admin_mails(ont)
      mail_sent_count = subscription.user.size + 1
      mails = all_emails.last(mail_sent_count)
      assert_equal mail_sent_count, mails.size # subscribed users + support mail

      first_user = subscription.user.first
      first_user.bring :email
      assert mails.first.subject.include?("Parsing Success")
      assert_equal [first_user.email], mails.first.to


      assert mails.last.subject.include?("Parsing Success")
      assert_equal (@@support_mails + admin_mails).uniq.sort, mails.last.to.sort

    ensure
      ont.delete if ont
      subscription.delete if subscription
    end
  end

  def test_remote_ontology_pull_notification
    begin
      ont_count, acronyms, ontologies = LinkedData::SampleData::Ontology.create_ontologies_and_submissions(ont_count: 1, submission_count: 1, process_submission: false)

      ont = LinkedData::Models::Ontology.find(ontologies[0].id).include(:acronym, :administeredBy, :name, :submissions).first
      ont_admins = Array.new(3) { LinkedData::Models::User.new }
      ont_admins.each_with_index do |user, i|
        user.username = "Test User #{i}"
        user.email = "tester_#{i}@example.org"
        user.password = "password"
        user.save
        assert user.valid?, user.errors
      end
    ont.administeredBy = ont_admins
    ont.save
    assert ont.valid?, ont.errors

    sub = ont.submissions.first
    sub.bring_remaining
    assert sub.valid?, sub.errors
    LinkedData::Utils::Notifications.remote_ontology_pull(sub)

    assert last_email_sent.subject.include? "[#{@@ui_name}] Load from URL failure for #{ont.name}"
    recipients = @@support_mails
    ont_admins.each do |user|
      recipients << user.email
    end
    assert_equal recipients.sort, last_email_sent.to.sort
    ensure
      ont_admins.each do |user|
        user.delete if user
      end
    end
  end

  def test_mail_options
    current_auth_type = LinkedData.settings.smtp_auth_type

    LinkedData.settings.smtp_auth_type = :none
    options = LinkedData::Utils::Notifier.mail_options
    expected_options = {
      address: LinkedData.settings.smtp_host,
      port: LinkedData.settings.smtp_port,
      domain: LinkedData.settings.smtp_domain
    }
    assert_equal options, expected_options

    # testing SMTP authentification-based login

    LinkedData.settings.smtp_auth_type = :plain
    options = LinkedData::Utils::Notifier.mail_options
    expected_options = {
      address: LinkedData.settings.smtp_host,
      port: LinkedData.settings.smtp_port,
      domain: LinkedData.settings.smtp_domain,
      user_name: LinkedData.settings.smtp_user,
      password: LinkedData.settings.smtp_password,
      authentication: LinkedData.settings.smtp_auth_type
    }
    assert_equal options, expected_options

    LinkedData.settings.smtp_auth_type = current_auth_type
  end
end
