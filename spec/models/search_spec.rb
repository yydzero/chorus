require "spec_helper"
describe Search do

  describe "with solr disabled" do
    before do
      @user = FactoryGirl.create(:user)
    end
    describe "new" do
      it "takes current user and search params" do
        search = Search.new(@user, :query => 'fries')
        search.current_user.should == @user
        search.query.should == 'fries'
      end
    end

    describe "search" do
      it "searches for all types with query" do
        search = Search.new(@user, :query => 'bob')
        search.search
        Sunspot.session.should be_a_search_for(User)
        Sunspot.session.should be_a_search_for(Instance)
        Sunspot.session.should be_a_search_for(Workspace)
        Sunspot.session.should be_a_search_for(Dataset)
        Sunspot.session.should have_search_params(:fulltext, 'bob')
        Sunspot.session.should have_search_params(:facet, :type_name)
        Sunspot.session.should have_search_params(:group, Proc.new {
          group :grouping_id do
            truncate
            limit 3
          end
        })
      end

      it "uses the page and per_page parameters" do
        search = Search.new(@user, :query => 'bob', :page => 4, :per_page => 42)
        search.search
        Sunspot.session.should have_search_params(:paginate, :page => 4, :per_page => 42)
      end

      describe "per_type" do
        it "performs secondary searches to pull back needed records" do
          any_instance_of(Sunspot::Search::AbstractSearch) do |search|
            stub(search).group_response { {} }
          end
          search = Search.new(@user, :query => 'bob', :per_type => 3)
          stub(search).num_found do
            hsh = Hash.new(0)
            hsh.merge({:users => 100, :instances => 100, :workspaces => 100, :workfiles => 100, :datasets => 100})
          end
          stub(search.search).each_hit_with_result { [] }
          search.models
          Sunspot.session.searches.length.should == search.models_to_search.length + 1
          search.models_to_search.each_with_index do |model, index|
            sunspot_search = Sunspot.session.searches[index+1]
            sunspot_search.should be_a_search_for(model)
            (search.models_to_search - [model]).each do |other_model|
              sunspot_search.should_not be_a_search_for(other_model)
            end
            sunspot_search.should have_search_params(:fulltext, 'bob')
            sunspot_search.should have_search_params(:paginate, :page => 1, :per_page => 3)
            sunspot_search.should_not have_search_params(:facet, :type_name)
          end
        end

        describe "entity_type" do
          it "searches for the provided models" do
            search = Search.new(@user, :query => 'bob', :entity_type => 'instance')
            search.search
            Sunspot.session.should_not be_a_search_for(User)
            Sunspot.session.should be_a_search_for(Instance)
          end
        end

        it "overrides page and per_page" do
          search = Search.new(@user, :query => 'bob', :per_type => 3, :page => 2, :per_page => 5)
          search.search
          Sunspot.session.should have_search_params(:paginate, :page => 1, :per_page => 100)
        end
      end
    end

    describe "search with a specific model" do
      it "only searches for that model" do
        search = Search.new(@user, :query => 'bob', :entity_type => 'user')
        search.search
        Sunspot.session.should be_a_search_for(User)
        Sunspot.session.should_not be_a_search_for(Instance)
        Sunspot.session.should have_search_params(:fulltext, 'bob')
        Sunspot.session.should_not have_search_params(:facet, :type_name)
      end
    end
  end

  context "with solr enabled" do
    let(:admin) { users(:admin) }
    let(:bob) { users(:bob) }
    let(:instance) { instances(:greenplum) }
    let(:public_workspace) { workspaces(:alice_public) }
    let(:private_workspace) { workspaces(:bob_private) }
    let(:private_workspace_not_a_member) { workspaces(:alice_private) }
    let(:private_workfile_hidden_from_bob) { workfiles(:alice_private) }
    let(:private_workfile_bob) { workfiles(:bob_private) }
    let(:public_workfile_bob) { workfiles(:bob_public) }
    let(:dataset) { datasets(:bobsearch_table) }

    before do
      reindex_solr_fixtures
    end

    describe "num_found" do
      it "returns a hash with the number found of each type" do
        VCR.use_cassette('search_solr_query_all_types_bob_as_bob') do
          search = Search.new(bob, :query => 'bobsearch')
          search.num_found[:users].should == 1
          search.num_found[:instances].should == 1
          search.num_found[:datasets].should == 1
        end
      end

      it "returns a hash with the total count for the given type" do
        VCR.use_cassette('search_solr_query_user_bob_as_bob') do
          search = Search.new(bob, :query => 'bobsearch', :entity_type => 'user')
          search.num_found[:users].should == 1
          search.num_found[:instances].should == 0
        end
      end
    end

    describe "users" do
      it "includes the highlighted attributes" do
        VCR.use_cassette('search_solr_query_all_types_bob_as_bob') do
          search = Search.new(bob, :query => 'bobsearch')
          user = search.users.first
          user.highlighted_attributes[:first_name][0].should == '<em>BobSearch</em>'
        end
      end

      it "returns the User objects found" do
        VCR.use_cassette('search_solr_query_all_types_bob_as_bob') do
          search = Search.new(bob, :query => 'bobsearch')
          search.users.length.should == 1
          search.users.first.should == bob
        end
      end
    end

    describe "instances" do
      it "includes the highlighted attributes" do
        VCR.use_cassette('search_solr_query_all_types_bob_as_bob') do
          search = Search.new(bob, :query => 'bobsearch')
          instance = search.instances.first
          instance.highlighted_attributes.length.should == 1
          instance.highlighted_attributes[:description][0].should == "Just for <em>bobsearch</em> and greenplumsearch"
        end
      end

      it "returns the Instance objects found" do
        VCR.use_cassette('search_solr_query_all_types_bob') do
          search = Search.new(bob, :query => 'bobsearch')
          search.instances.length.should == 1
          search.instances.first.should == instance
        end
      end
    end

    describe "datasets" do
      it "includes the highlighted attributes" do
        VCR.use_cassette('search_solr_query_all_types_bob_as_bob') do
          search = Search.new(bob, :query => 'bobsearch')
          dataset = search.datasets.first
          dataset.highlighted_attributes.length.should == 3
          dataset.highlighted_attributes[:name][0].should == "<em>bobsearch</em>_table"
          dataset.highlighted_attributes[:database_name][0].should == "<em>bobsearch</em>_database"
          dataset.highlighted_attributes[:schema_name][0].should == "<em>bobsearch</em>_schema"
        end
      end

      it "returns the Dataset objects found" do
        VCR.use_cassette('search_solr_query_all_types_bob') do
          search = Search.new(bob, :query => 'bobsearch')
          search.datasets.length.should == 1
          search.datasets.first.should == dataset
        end
      end
    end

    describe "highlighted comments" do
      it "includes highlighted comments in the highlighted_attributes" do
        VCR.use_cassette('search_solr_query_all_types_greenplum_as_bob') do
          search = Search.new(bob, :query => 'greenplumsearch')
          search.instances.length.should == 2
          instance_with_comments = search.instances[1]
          instance_with_comments.search_result_comments.length.should == 2
          instance_with_comments.search_result_comments[0][:highlighted_attributes][:body][0].should == "no, not <em>greenplumsearch</em>"
        end
      end
    end

    describe "per_type" do
      it "does not return more than per_type of any model" do
        VCR.use_cassette('search_solr_query_all_per_type_1_as_bob') do
          search = Search.new(bob, :query => 'alphasearch', :per_type => 1)
          search.users.length.should == 1
          search.num_found[:users].should > 1
        end
      end
    end

    describe "workspace permissions" do
      it "returns public and member workspaces, but not private ones" do
        VCR.use_cassette('search_solr_query_workspaces_bob_as_bob') do
          search = Search.new(bob, :query => 'bobsearch', :entity_type => :workspace)
          search.workspaces.should include(public_workspace)
          search.workspaces.should include(private_workspace)
          search.workspaces.should_not include(private_workspace_not_a_member)
        end
      end

      it "returns everything for admins" do
        VCR.use_cassette('search_solr_query_workspaces_bob_as_admin') do
          search = Search.new(admin, :query => 'bobsearch', :entity_type => :workspace)
          search.workspaces.should include(public_workspace)
          search.workspaces.should include(private_workspace)
          search.workspaces.should include(private_workspace_not_a_member)
        end
      end
    end

    describe "workfile permissions" do
      it "returns workfiles for public and member workspaces, but not private ones" do
        VCR.use_cassette('search_solr_query_workfiles_bob_as_bob') do
          search = Search.new(bob, :query => 'bobsearch', :entity_type => :workfile)
          search.workfiles.should include(public_workfile_bob)
          search.workfiles.should include(private_workfile_bob)
          search.workfiles.should_not include(private_workfile_hidden_from_bob)
        end
      end

      it "returns workfiles for every workspace for admins" do
        VCR.use_cassette('search_solr_query_workfiles_bob_as_admin') do
          search = Search.new(admin, :query => 'bobsearch', :entity_type => :workfile)
          search.workfiles.should include(public_workfile_bob)
          search.workfiles.should include(private_workfile_bob)
          search.workfiles.should include(private_workfile_hidden_from_bob)
        end
      end
    end
  end
end