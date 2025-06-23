require "pact_broker/ui/controllers/base_controller"
require "pact_broker/ui/view_models/index_items"
require "haml"

# TODO handle 404 gracefully

module PactBroker
  module UI
    module Controllers
      class Groups < Base
        include PactBroker::Services

        get ":name" do
          erb :'groups/show.html', {
              locals: locals(tab: "details")
            }, {
              layout: "layouts/main",
            }
        end

        get ":name/network" do
          erb :'groups/show.html', {
              locals: locals(tab: "network")
            }, {
              layout: "layouts/main",
            }
        end

        def locals(overrides)
          pacticipant = pacticipant_service.find_pacticipant_by_name(params[:name])

          if pacticipant
            production_envs = environment_service.find_all.select { |env| env.respond_to?(:production?) && env.production? }.map(&:name)
            main_branch = pacticipant.main_branch
            main_version = version_service.find_latest_by_pacticipant_name_and_branch_name(pacticipant.name, main_branch) if main_branch
            can_i_deploy_data = check_can_i_deploy_pacticipant_version_to_environments(pacticipant.name, main_version.number, production_envs) if main_version

            if !can_i_deploy_data
              logger.warn "No main version found for pacticipant '#{pacticipant.name}' and branch '#{main_branch}'"
              can_i_deploy_data = {}
            end

            deployed_versions = deployed_version_service.find_currently_deployed_versions_for_pacticipant(pacticipant) 
            released_versions = released_version_service.find_currently_supported_versions_for_pacticipant(pacticipant)

            branch_names = branch_service.find_all_branches_for_pacticipant(pacticipant).sort_by(&:updated_at).reverse.map(&:name)
            branch_names = branch_names.select { |branch| branch != main_branch } if main_branch
            
            can_i_merge_data = check_can_i_merge_branches pacticipant.name, branch_names
          end

          {
            csv_path: "#{base_url}/groups/#{ERB::Util.url_encode(params[:name])}.csv",
            max_pacticipants: PactBroker.configuration.network_diagram_max_pacticipants,
            pacticipant_name: params[:name],
            repository_url: pacticipant&.repository_url,
            base_url: base_url,
            pacticipant: pacticipant,
            details_url: "#{base_url}/pacticipants/#{ERB::Util.url_encode(params[:name])}",
            network_url: "#{base_url}/pacticipants/#{ERB::Util.url_encode(params[:name])}/network?maxPacticipants=#{PactBroker.configuration.network_diagram_max_pacticipants}",
            deployed_versions: deployed_versions,
            released_versions: released_versions,
            can_i_deploy_data: can_i_deploy_data,
            can_i_merge_data: can_i_merge_data
          }.merge(overrides)
        rescue => e
          logger.error "Error in Groups controller: #{e.message}"
          logger.error e.backtrace.join("\n")
          halt 500, "Internal Server Error"
        end

        private

        def check_can_i_merge_pacticipant_version (pacticipant_name, pacticipant_version)
          selectors = PactBroker::Matrix::UnresolvedSelector.from_hash(
            pacticipant_name: pacticipant_name, 
            pacticipant_version_number: pacticipant_version
          )
           
          options = { main_branch: true, latest: true, latestby: "cvp" }
          query_results = matrix_service.can_i_deploy [selectors], options
          decorated = PactBroker::Api::Decorators::MatrixDecorator.new(query_results)

          { can_merge: decorated.deployable, reason: decorated.reason }
        end

        def check_can_i_deploy_pacticipant_version(pacticipant_name, pacticipant_version, environment)
          selectors = PactBroker::Matrix::UnresolvedSelector.from_hash(
            pacticipant_name: pacticipant_name, 
            pacticipant_version_number: pacticipant_version,
          ) 
          options = { latestby: "cvp", environment_name: environment }
          query_results = matrix_service.can_i_deploy [selectors], options
          decorated = PactBroker::Api::Decorators::MatrixDecorator.new(query_results) 
          {
            deployable: decorated.deployable,
            reason: decorated.reason,
            executed_at: Time.now.utc.iso8601
          }
        end

        def check_can_i_deploy_pacticipant_version_to_environments(pacticipant_name, pacticipant_version, environments)
          can_i_deploy_data = {}
          environments.each do |env|
            begin
              result = check_can_i_deploy_pacticipant_version(pacticipant_name, pacticipant_version, env)
              can_i_deploy_data[env] = {
                deployable: result[:deployable],
                executed_at: result[:executed_at],
                reason: result[:reason]
              }
            end
          end
          can_i_deploy_data
        end

        def check_can_i_merge_branches(pacticipant_name, branches)
          can_i_merge_data = {}
          branches.each do |branch|
            begin
              version = version_service.find_latest_by_pacticipant_name_and_branch_name(pacticipant_name, branch)
              result = check_can_i_merge_pacticipant_version(pacticipant_name, version.number) 

              can_i_merge_data[branch] = {
                can_merge: result[:can_merge],
                executed_at: Time.now.utc.iso8601,
                reason: result[:reason]
              } 
            end
          end
          can_i_merge_data
        end
      end
    end
  end
end