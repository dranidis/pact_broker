require "pact/doc/markdown/interaction_renderer"
require "pact/doc/sort_interactions"
require "rack/utils"

module Pact
  module Doc
    module Markdown
      class ConsumerContractRenderer

        def initialize consumer_contract
          @consumer_contract = consumer_contract
        end

        def self.call consumer_contract
          new(consumer_contract).call
        end

        def call
          title + full_interactions
        end

        private

        attr_reader :consumer_contract

        def title
          "# A pact between #{consumer_name} and #{provider_name}\n\n"
        end

        def interaction_renderers
          @interaction_renderers ||= sorted_interactions.collect{|interaction| InteractionRenderer.new interaction, @consumer_contract}
        end

        def summaries_title
          "### Requests from #{consumer_name} to #{provider_name}\n\n"
        end

        def summaries
          interaction_renderers.collect(&:render_summary).join
        end

        def full_interactions
          # Group by path first
          grouped_by_path = interaction_renderers.group_by do |renderer|
            path = renderer.interaction.request_path

            # request_path can be a String or a Term
            # If it's a Term, we need to generate it to get the actual path
            # If it's a String, we can use it directly
            # If it's neither, we return a placeholder string
            # This ensures we can handle both cases without errors
            if path.is_a?(String)
              path
            elsif path.respond_to?(:generate) && path.generate.is_a?(String)
              path.generate
            else
              logger.error "⚠️ ERROR: Unexpected path or generate result: #{path.inspect} in interaction '#{renderer.interaction.description}'. Method: ConsumerContractRenderer::full_interactions "
              "RequestPathNotCorrectlyIdentified"
            end            
          end

          # Sort paths alphabetically
          sorted_paths = grouped_by_path.keys.sort_by(&:downcase)

          # Build output with collapsible sections
          sorted_paths.map do |path|
            method_groups = grouped_by_path[path].group_by { |renderer| renderer.interaction.request_method.upcase }

            # Don't sort methods — keep order from input
            method_groups.map do |method, renderers|
              method = case method
                       when "FAKE_ASYNC_METHOD" then "ASYNC"
                       when "FAKE_SYNC_METHOD" then "SYNC"
                       else method.upcase
                       end
 
              endpoint = "#{method} #{path}"

              <<~HTML
                <details class="endpoint-group">
                  <summary>
                    <span class="arrow-box" aria-hidden="true"></span>
                    <code class="endpoint-code">#{h endpoint}</code>
                  </summary>
                  <div class="interaction-group">
                    #{renderers.map(&:render_full_interaction).join}
                  </div>
                </details>
              HTML
            end.join("\n")
          end.join("\n")
        end
        

        def request_method
          request["method"].to_s.upcase
        end

        def sorted_interactions
          SortInteractions.call(consumer_contract.interactions)
        end

        def consumer_name
          h(markdown_escape consumer_contract.consumer.name)
        end

        def provider_name
          h(markdown_escape consumer_contract.provider.name)
        end

        def markdown_escape string
          string.gsub("*","\\*").gsub("_","\\_")
        end

        def h(text)
          Rack::Utils.escape_html(text)
        end
      end
    end
  end
end
