# frozen_string_literal: true

module Liquid
  class Render < Tag
    SYNTAX = /(#{QuotedString})#{QuotedFragment}*/o

    disable_tags "include"

    attr_reader :template_name_expr, :attributes

    def initialize(tag_name, markup, options)
      super

      raise SyntaxError, options[:locale].t("errors.syntax.render") unless markup =~ SYNTAX

      template_name = Regexp.last_match(1)

      @template_name_expr = Expression.parse(template_name)

      @attributes = {}
      markup.scan(TagAttributes) do |key, value|
        @attributes[key] = Expression.parse(value)
      end
    end

    def render_to_output_buffer(context, output)
      render_tag(context, output)
    end

    def render_tag(context, output)
      # Though we evaluate this here we will only ever parse it as a string literal.
      template_name = context.evaluate(@template_name_expr)
      raise ArgumentError, options[:locale].t("errors.argument.include") unless template_name

      partial = PartialCache.load(
        template_name,
        context: context,
        parse_context: parse_context
      )

      inner_context = context.new_isolated_subcontext
      inner_context.template_name = template_name
      inner_context.partial = true
      @attributes.each do |key, value|
        inner_context[key] = context.evaluate(value)
      end
      partial.render_to_output_buffer(inner_context, output)

      output
    end

    class ParseTreeVisitor < Liquid::ParseTreeVisitor
      def children
        [
          @node.template_name_expr,
        ] + @node.attributes.values
      end
    end
  end

  Template.register_tag('render', Render)
end
