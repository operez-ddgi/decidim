# frozen_string_literal: true

module Decidim
  module Admin
    # A command with all the business logic when officializing a user.
    class OfficializeUser < Rectify::Command
      # Public: Initializes the command.
      #
      # form - The officialization form.
      def initialize(form)
        @form = form
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when the officialization suceeds.
      # - :invalid when the form is invalid.
      #
      # Returns nothing.
      def call
        return broadcast(:invalid) unless form.valid?

        officialize_user

        Decidim::EventsManager.publish(
          event: "decidim.events.users.user_officialized",
          event_class: Decidim::ProfileUpdatedEvent,
          resource: form.user,
          recipient_ids: form.user.followers.pluck(:id)
        )

        broadcast(:ok, form.user)
      end

      private

      attr_reader :form

      def officialize_user
        form.user.update!(
          officialized_at: Time.current,
          officialized_as: form.officialized_as
        )
      end
    end
  end
end