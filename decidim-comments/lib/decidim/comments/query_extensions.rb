# frozen_string_literal: true

module Decidim
  module Comments
    # This module's job is to extend the API with custom fields related to
    # decidim-comments.
    module QueryExtensions
      # Public: Extends a type with `decidim-comments`'s fields.
      #
      # type - A GraphQL::BaseType to extend.
      #
      # Returns nothing.
      def self.define(type)
        type.field :commentable do
          type !CommentableType

          argument :id, !types.String, "The commentable's ID"
          argument :type, !types.String, "The commentable's class name. i.e. `Decidim::ParticipatoryProcess`"

          resolve lambda { |_obj, args, _ctx|
            args[:type].constantize.find(args[:id])
          }
        end

        type.field :commentsMetric, Comments::CommentsMetricType, "Decidim's CommentMetric data." do
          resolve lambda { |_obj, _args, ctx|
            ctx[:current_organization]
          }
        end
      end
    end
  end
end
