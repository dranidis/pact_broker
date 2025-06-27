require "pact_broker/ui/app"
require "pact_broker/api/decorators/matrix_decorator"

describe "Pacticipants (can-i-deploy and can-i-merge)" do
  let(:app) { PactBroker::UI::App.new }
  let(:params) { {} }

  before do
    td.create_consumer("Foo")
      .create_environment("production", { production: true })
  end

  subject { get("/pacticipants/Foo") }

  describe "GET" do
    it "returns a success response" do
      expect(subject.status).to eq 200
    end

    it "returns the pacticipant page" do
      expect(subject.body).to include(">Foo</h1>")
    end

    it "returns can-i-deploy failure when no main branch set" do
      expect(subject.body).to include("No main branch set for this pacticipant.")
    end

    it "returns can i deploy failure when a pact is published on the main branch but not verified" do
      td.create_consumer("Foo1", main_branch: "foo1main")
        .create_provider("Foo2", main_branch: "foo2main")
        .publish_pact(consumer_name: "Foo1", consumer_version_number: "1", provider_name: "Foo2", branch: "foo1main")

      newsubject = get("/pacticipants/Foo1")
      expect(newsubject.body).to include("There is no verified pact between version 1 of Foo1 and a version of Foo2 currently in production (no version is currently recorded as deployed/released in this environment)")
    end

    it "returns can i deploy failure when a pact is published on the main branch but not verified (no provider in production)" do
      td.create_consumer("Foo1", main_branch: "foo1main")
        .create_provider("Foo2", main_branch: "foo2main")
        .publish_pact(consumer_name: "Foo1", consumer_version_number: "1", provider_name: "Foo2", branch: "foo1main")

      newsubject = get("/pacticipants/Foo1")

      expect(newsubject.body).to include("Can I Deploy badge for foo1main in production")
      expect(newsubject.body).to include("There is no verified pact between version 1 of Foo1 and a version of Foo2 currently in production (no version is currently recorded as deployed/released in this environment)")
    end    

    it "returns can i deploy success when a pact is published on the main branch but it is verified" do
      td.create_consumer("Foo1", main_branch: "foo1main")
        .create_provider("Foo2", main_branch: "foo2main")
        .publish_pact(consumer_name: "Foo1", consumer_version_number: "1", provider_name: "Foo2", branch: "foo1main")
        .create_verification(provider_version: "1315e0b1924cb6f42751f977789be3559373033a", branch: "foo2main", success: true)
        .create_deployed_version_for_provider_version(environment_name: "production", currently_deployed: true)

      newsubject = get("/pacticipants/Foo1")
      expect(newsubject.body).to include("Can I Deploy badge for foo1main in production")
      expect(newsubject.body).not_to match(/There is no verified pact between version 1 of Foo1 and .* version of Foo2 currently in production/)
    end    

    it "returns can i deploy failure when a pact is published on the main branch but it is not verified yet" do
      td.create_consumer("Foo1", main_branch: "foo1main")
        .create_provider("Foo2", main_branch: "foo2main")
        .publish_pact(consumer_name: "Foo1", consumer_version_number: "1", provider_name: "Foo2", branch: "foo1main")
        .create_verification(provider_version: "1315e0b1924cb6f42751f977789be3559373033a", branch: "foo2main", success: true)
        .create_deployed_version_for_provider_version(environment_name: "production", currently_deployed: true)
        .publish_pact(consumer_name: "Foo1", consumer_version_number: "2", provider_name: "Foo2", branch: "foo1main")

      newsubject = get("/pacticipants/Foo1")
      expect(newsubject.body).to include("Can I Deploy badge for foo1main in production")
      expect(newsubject.body).to include("There is no verified pact between version 2 of Foo1 and the version of Foo2 currently in production")
    end       

    it "returns can i merge failure when a pact is published on a feature branch but it is not verified yet" do
      td.create_consumer("Foo1", main_branch: "foo1main")
        .create_provider("Foo2", main_branch: "foo2main")
        .publish_pact(consumer_name: "Foo1", consumer_version_number: "1", provider_name: "Foo2", branch: "foo1main")
        .create_verification(provider_version: "p_main_version", branch: "foo2main", success: true)
        .create_consumer_version("6c992f831da299364cf31be6008ee4752189f6d4", branch: "feat/new-thing")
        .publish_pact(consumer_name: "Foo1", consumer_version_number: "2", provider_name: "Foo2", branch: "feat/new-thing")

      newsubject = get("/pacticipants/Foo1")
      expect(newsubject.body).to include(">N</span>")
      expect(newsubject.body).to include("There is no verified pact between version 2 of Foo1 and the latest version of Foo2 from branch foo2main (p_main_version)")
    end  

    it "returns can i merge success when a pact is published on a feature branch and it is verified by the provider's main branch" do
      td.create_consumer("Foo1", main_branch: "foo1main")
        .create_provider("Foo2", main_branch: "foo2main")
        .publish_pact(consumer_name: "Foo1", consumer_version_number: "1", provider_name: "Foo2", branch: "foo1main")
        .create_verification(provider_version: "p_main_version", branch: "foo2main", success: true)
        .create_consumer_version("6c992f831da299364cf31be6008ee4752189f6d4", branch: "feat/new-thing")
        .publish_pact(consumer_name: "Foo1", consumer_version_number: "2", provider_name: "Foo2", branch: "feat/new-thing")
        .create_verification(provider_version: "p_main_version", branch: "foo2main", success: true)


      newsubject = get("/pacticipants/Foo1")
      expect(newsubject.body).to include(">Y</span>")
      expect(newsubject.body).not_to include("There is no verified pact between version 2 of Foo1 and the latest version of Foo2 from branch foo2main (p_main_version)")
    end  

  end
end
