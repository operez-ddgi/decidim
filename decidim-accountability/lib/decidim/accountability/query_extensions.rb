# frozen_string_literal: true

module Decidim
  module Accountability
    # This module's job is to extend the API with custom fields related to
    # decidim-proposals.
    module QueryExtensions
      # Public: Extends a type with `decidim-proposals`'s fields.
      #
      # type - A GraphQL::BaseType to extend.
      #
      # Returns nothing.
      def self.define(type)
        type.field :resultMetric, Accountability::ResultMetricType, "Decidim's ResultMetric data." do
          resolve lambda { |_obj, _args, ctx|
            ctx[:current_organization]
          }
        end
      end
    end
  end
end
