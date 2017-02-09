require "spec_helper"

describe "Explore meetings", type: :feature do
  include_context "feature"
  let(:manifest_name) { "meetings" }

  let(:meetings_count) { 5 }
  let!(:meetings) do
    create_list(:meeting, meetings_count, feature: feature)
  end

  before do
    visit_feature
  end

  context "index" do
    it "shows all meetings for the given process" do
      expect(page).to have_selector("article.card", count: meetings_count)

      meetings.each do |meeting|
        expect(page).to have_content(translated(meeting.title))
      end
    end

    context "filtering" do
      it "allows searching by text" do
        within ".filters" do
          fill_in :filter_search_text, with: translated(meetings.first.title)
        end

        expect(page).to have_css(".card--meeting", count: 1)
        expect(page).to have_content(translated(meetings.first.title))
      end

      it "allows filtering by date" do
        past_meeting = create(:meeting, feature: feature, start_time: 1.day.ago)
        visit_feature

        within ".filters" do
          choose "Past"
        end

        expect(page).to have_css(".card--meeting", count: 1)
        expect(page).to have_content(translated(past_meeting.title))

        within ".filters" do
          choose "Upcoming"
        end

        expect(page).to have_css(".card--meeting", count: 5)
      end

      it "allows fitlering by scope" do
        scope = create(:scope, organization: organization)
        meeting = meetings.first
        meeting.scope = scope
        meeting.save

        visit_feature

        within ".filters" do
          check scope.name
        end

        expect(page).to have_css(".card--meeting", count: 1)
      end
    end
  end

  context "show" do
    let(:meetings_count) { 1 }
    let(:meeting) { meetings.first }

    before do
      meeting.update_attributes(
        start_time: DateTime.new(Time.current.year + 1, 12, 13, 14, 15),
        end_time: DateTime.new(Time.current.year + 1, 12, 13, 16, 17)
      )
      click_link translated(meeting.title)
    end

    it "shows all meeting info" do
      expect(page).to have_i18n_content(meeting.title)
      expect(page).to have_i18n_content(meeting.description)
      expect(page).to have_i18n_content(meeting.location)
      expect(page).to have_i18n_content(meeting.location_hints)
      expect(page).to have_content(meeting.address)

      within ".section.view-side" do
        expect(page).to have_content(13)
        expect(page).to have_content(/December/i)
        expect(page).to have_content("14:15 - 16:17")
      end
    end

    context "without category or scope" do
      it "does not show any tag" do
        expect(page).not_to have_selector("ul.tags.tags--meeting")
      end
    end

    context "with a category" do
      let(:meeting) do
        meeting = meetings.first
        meeting.category = create(:category, participatory_process: participatory_process)
        meeting.save
        meeting
      end

      it "shows tags for category" do
        expect(page).to have_selector("ul.tags.tags--meeting")
        within "ul.tags.tags--meeting" do
          expect(page).to have_content(translated(meeting.category.name))
        end
      end

      it "links to the filter for this category" do
        within "ul.tags.tags--meeting" do
          click_link translated(meeting.category.name)
        end
        expect(page).to have_select("filter_category_id", selected: translated(meeting.category.name))
      end
    end

    context "with a scope" do
      let(:meeting) do
        meeting = meetings.first
        meeting.scope = create(:scope, organization: organization)
        meeting.save
        meeting
      end

      it "shows tags for scope" do
        expect(page).to have_selector("ul.tags.tags--meeting")
        within "ul.tags.tags--meeting" do
          expect(page).to have_content(meeting.scope.name)
        end
      end

      it "links to the filter for this scope" do
        within "ul.tags.tags--meeting" do
          click_link meeting.scope.name
        end
        expect(page).to have_checked_field(meeting.scope.name)
      end
    end

    context "with linked proposals" do
      let(:proposal_feature) do
        create(:feature, manifest_name: :proposals, participatory_process: meeting.feature.participatory_process)
      end
      let(:proposals) { create_list(:proposal, 3, feature: proposal_feature) }

      before do
        meeting.link_resources(proposals, "proposals_from_meeting")
        visit_feature
        click_link translated(meeting.title)
      end

      it "shows related proposals" do
        proposals.each do |proposal|
          expect(page).to have_content(proposal.title)
          expect(page).to have_content(proposal.author_name)
          expect(page).to have_content(proposal.votes.size)
        end
      end
    end

    context "with linked results" do
      let(:result_feature) do
        create(:feature, manifest_name: :results, participatory_process: meeting.feature.participatory_process)
      end
      let(:results) { create_list(:result, 3, feature: result_feature) }

      before do
        meeting.link_resources(results, "meetings_through_proposals")
        visit_feature
        click_link translated(meeting.title)
      end

      it "shows related results" do
        results.each do |result|
          expect(page).to have_i18n_content(result.title)
        end
      end
    end

    let(:attached_to) { meeting }
    it_behaves_like "has attachments"

    context "when the meeting is closed" do
      let!(:meeting) { create(:meeting, :closed, feature: feature) }

      before do
        meeting
        visit_feature
        click_link translated(meeting.title)
      end

      it "shows the closing report" do
        expect(page).to have_i18n_content(meeting.closing_report)

        within ".definition-data" do
          expect(page).to have_content(meeting.attendees_count)
          expect(page).to have_content(meeting.contributions_count)
          expect(page).to have_content(meeting.attending_organizations)
        end
      end
    end
  end
end
