# typed: strict
# frozen_string_literal: true

begin
  require "active_storage"
  require "active_storage/reflection"
rescue LoadError
  return
end

module Tapioca
  module Compilers
    module Dsl
      # `Tapioca::Compilers::Dsl::ActiveStorage` decorates RBI files for subclasses of
      # `ActiveRecord::Base` that declare [one](https://edgeguides.rubyonrails.org/active_storage_overview.html#has-one-attached)
      # or [many](https://edgeguides.rubyonrails.org/active_storage_overview.html#has-many-attached) attachments.
      #
      # For example, with the following `ActiveRecord::Base` subclass:
      #
      # ~~~rb
      # class Post < ApplicationRecord
      #  has_one_attached :photo
      #  has_many_attached :blogs
      # end
      # ~~~
      #
      # this generator will produce the RBI file `post.rbi` with the following content:
      #
      # ~~~rbi
      # # typed: strong
      #
      # class Post
      #   sig { returns(ActiveStorage::Attached::Many) }
      #   def blogs; end
      #
      #   sig { params(attachable: T.untyped).returns(T.untyped) }
      #   def blogs=(attachable); end
      #
      #   sig { returns(ActiveStorage::Attached::One) }
      #   def photo; end
      #
      #   sig { params(attachable: T.untyped).returns(T.untyped) }
      #   def photo=(attachable); end
      # end
      # ~~~
      class ActiveStorage < Base
        extend T::Sig

        sig do
          override.params(root: RBI::Tree,
            constant: T.all(Module, ::ActiveStorage::Reflection::ActiveRecordExtensions::ClassMethods)).void
        end
        def decorate(root, constant)
          return if constant.reflect_on_all_attachments.empty?

          root.create_path(constant) do |scope|
            constant.reflect_on_all_attachments.each do |reflection|
              type = type_of(reflection)
              name = reflection.name.to_s
              scope.create_method(
                name,
                return_type: type
              )
              scope.create_method(
                "#{name}=",
                parameters: [create_param("attachable", type: "T.untyped")],
                return_type: "T.untyped"
              )
            end
          end
        end

        sig { override.returns(T::Enumerable[Module]) }
        def gather_constants
          descendants_of(::ActiveRecord::Base)
            .reject(&:abstract_class?)
            .grep(::ActiveStorage::Reflection::ActiveRecordExtensions::ClassMethods)
        end

        private

        sig do
          params(reflection: ActiveRecord::Reflection::MacroReflection).returns(String)
        end
        def type_of(reflection)
          case reflection
          when ::ActiveStorage::Reflection::HasOneAttachedReflection
            "ActiveStorage::Attached::One"
          when ::ActiveStorage::Reflection::HasManyAttachedReflection
            "ActiveStorage::Attached::Many"
          else
            "T.untyped"
          end
        end
      end
    end
  end
end