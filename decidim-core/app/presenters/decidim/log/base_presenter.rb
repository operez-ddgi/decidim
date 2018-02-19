# frozen_string_literal: true

module Decidim
  module Log
    # This class holds the logic to present a resource for any activity log.
    # It is supposed to be a base class for all other log renderers, as it defines
    # some helpful methods that later presenters can use.
    #
    # Most presenters that inherit from this class will only need to overwrite
    # the `action_string` method, which defines what I18n key will be used for
    # each action. Other methods that might be interesting to overwrite are those
    # named `present_*`. Check the source code and the method docs to see how they
    # work.
    #
    # See `Decidim::ActionLog#render_log` for more info on the log types and
    # presenters.
    #
    # Usage should be automatic and you shouldn't need to call this class
    # directly, but here's an example:
    #
    #    action_log = Decidim::ActionLog.last
    #    view_helpers # => this comes from the views
    #    BasePresenter.new(action_log, view_helpers).present
    class BasePresenter
      # Public: Initializes the presenter.
      #
      # action_log - An instance of Decidim::ActionLog
      # view_helpers - An object holding the view helpers at the render time.
      #   Most probably should come automatically from the views.
      def initialize(action_log, view_helpers)
        @action_log = action_log
        @view_helpers = view_helpers
      end

      # Public: Renders the given `action_log`.
      #
      # action_log - An instance of Decidim::ActionLog.last
      # view_helpers - An object holding the view helpers at the render time.
      #   Most probably should come automatically from the views.
      #
      # Returns an HTML-safe String.
      def present
        present_action_log
      end

      private

      attr_reader :action_log, :view_helpers
      alias h view_helpers

      delegate :action, to: :action_log

      # Private: Caches the version that holds the changeset to display.
      #
      # Returns a PaperTrail::Version.
      def version
        @version ||= PaperTrail::Version.where(id: action_log.extra.dig("version", "id")).first
      end

      # Private: Caches the object that will be responsible of presenting the space
      # where the action is performed.
      #
      # Returns an object that responds to `present`.
      def space_presenter
        @space_presenter ||= Decidim::Log::SpacePresenter.new(
          action_log.participatory_space,
          h,
          action_log.extra["participatory_space"]
        )
      end

      # Private: Caches the object that will be responsible of presenting the resource
      # affected by the given action.
      #
      # Returns an object that responds to `present`.
      def resource_presenter
        @resource_presenter ||= Decidim::Log::ResourcePresenter.new(action_log.resource, h, action_log.extra["resource"])
      end

      # Private: Caches the object that will be responsible of presenting the user
      # that performed the given action.
      #
      # Returns an object that responds to `present`.
      def user_presenter
        @user_presenter ||= Decidim::Log::UserPresenter.new(action_log.user, h, action_log.extra["user"])
      end

      # Private: Presents the date the action was performed.
      #
      # Returns an HTML-safe String.
      def present_log_date
        h.content_tag(:div, class: "logs__log__date") do
          h.localize(action_log.created_at, format: :decidim_short)
        end
      end

      # Private: Presents the dropdown, if needed, to display the diff.
      #
      # Returns an HTML-safe String.
      def present_dropdown
        return h.content_tag(:div, "", class: "logs__log__actions") unless has_diff?

        h.content_tag(:div, class: "logs__log__actions") do
          h.content_tag(:a, "", class: "logs__log__actions-dropdown", data: { toggle: h.dom_id(action_log) })
        end
      end

      # Private presents the explanation of the action. It will
      # hold the author name, the action type, the resource affected
      # and the participatory space the resource belongs to.
      #
      # Returns an HTML-safe String.
      def present_explanation
        h.content_tag(:div, class: "logs__log__explanation") do
          I18n.t(
            action_string,
            i18n_params
          ).html_safe
        end
      end

      # Private: Presents the contents of the log.
      # It holds the date of the action and the explanation.
      #
      # Returns an HTML-safe String.
      def present_content
        h.content_tag(:div, class: "logs__log__content") do
          present_log_date + present_explanation + present_dropdown
        end
      end

      # Private: Caches the object that will be responsible of presenting the diff
      # of the given action.
      #
      # Returns an object that responds to `present` and `visible?`.
      def diff_presenter
        @diff_presenter ||= Decidim::Log::DiffPresenter.new(
          changeset,
          view_helpers,
          show_previous_value?: action.to_s != "create"
        )
      end

      # Private: Presents the diff of the log, if needed
      # It holds the names of the attributes that have changed,
      # and the old and new values.
      #
      # Returns an HTML-safe String.
      def present_diff
        return "".html_safe unless has_diff?

        diff_presenter.present
      end

      # Private: Presents the log content with a default form.
      #
      # Returns an HTML-safe String.
      def present_action_log
        h.content_tag(:li, id: h.dom_id(action_log), class: "logs__log", data: { toggler: ".logs__log--expanded" }) do
          h.concat(present_content)
          h.concat(present_diff)
        end
      end

      # Private: Finds the name of the I18n key that will be used for the
      # current log action.
      #
      # Returns a String.
      def action_string
        case action.to_s
        when "create"
          "decidim.log.base_presenter.create"
        when "update"
          "decidim.log.base_presenter.update"
        else
          "decidim.log.base_presenter.unknown_action"
        end
      end

      # Private: The params to be sent to the i18n string.
      #
      # Returns a Hash.
      def i18n_params
        {
          user_name: user_presenter.present,
          resource_name: resource_presenter.present,
          space_name: space_presenter.present
        }
      end

      # Private: Calculates if the diff has to be shown or not.
      #
      # Returns a Boolean.
      def has_diff?
        %w(update create).include?(action.to_s) && version.present?
      end

      # Private: Sets a default list of attributes to be rendered in
      # the diff, and how they should be rendered. Custom renderers
      # will probably want to overwrite this method to fulfill their
      # needs.
      #
      # When the value is `nil`, then it renders all fields.
      #
      # Returns a Hash or `nil`.
      def diff_fields_mapping
        nil
      end

      # Private: The I18n scope where the resource fields are found, so
      # the diff can properly generate the labels.
      #
      # Returns a String.
      def i18n_labels_scope; end

      # Private: Calculates the changeset to be rendered. Uses the values
      # from the `diff_fields_mapping` method.
      #
      # Returns an Array of Hashes.
      def changeset
        Decidim::Log::DiffChangesetCalculator.new(
          version.changeset,
          diff_fields_mapping,
          i18n_labels_scope
        ).changeset
      end
    end
  end
end