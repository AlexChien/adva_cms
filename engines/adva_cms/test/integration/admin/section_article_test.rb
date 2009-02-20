require File.expand_path(File.dirname(__FILE__) + '/../../test_helper' )

module IntegrationTests
  class AdminSectionArticleTest < ActionController::IntegrationTest
    def setup
      super
      @section = Section.find_by_title 'a section'
      @site = @section.site

      use_site! @site
      stub(Time).now.returns Time.utc(2008, 1, 2)
    end
    
    # FIXME add reordering articles
    test "Admin creates an article, previews, edits and deletes it" do
      login_as_admin
      visit_admin_articles_index_page
      create_a_new_article
      revise_the_article
      preview_article
      delete_article
    end

    test "posting a German article in English interface" do
      login_as_admin
      visit_admin_articles_index_page
      create_a_new_de_article
      assert_equal 'de', @controller.instance_variable_get(:@content_locale)
      revise_the_de_article
      preview_de_article
      delete_article
    end
    
    def visit_admin_articles_index_page
      visit "/admin/sites/#{@site.id}/sections/#{@section.id}/articles"
    end

    def create_a_new_article
      click_link "Create a new article"
      fill_in 'article[title]', :with => 'the article title'
      fill_in 'article[body]',  :with => 'the article body'
      click_button 'Save'
      request.url.should =~ %r(/admin/sites/\d+/sections/\d+/articles/\d+/edit)
    end

    def create_a_new_de_article
      click_link "Create a new article"
      select 'de', :from => 'content_locale'
      assert_response :success 
      fill_in 'article[title]', :with => 'the article title [de]'
      fill_in 'article[body]',  :with => 'the article body [de]'
      click_button 'Save'
      request.url.should =~ %r(/admin/sites/\d+/sections/\d+/articles/\d+/edit)
    end

    def revise_the_article
      fill_in 'article[title]', :with => 'the revised article title'
      fill_in 'article[body]',  :with => 'the revised article body'
      click_button 'Save'
      request.url.should =~ %r(/admin/sites/\d+/sections/\d+/articles/\d+/edit)
      @back_url = request.url
    end

    def revise_the_de_article
      fill_in 'article[title]', :with => 'the revised article title [de]'
      fill_in 'article[body]',  :with => 'the revised article body [de]'
      click_button 'Save'
      request.url.should =~ %r(/admin/sites/\d+/sections/\d+/articles/\d+/edit)
      @back_url = request.url
    end

    def preview_article
      click_link 'Preview this article'
      request.url.should == "http://#{@site.host}/articles/the-article-title?cl=en"
    end

    def preview_de_article
      click_link 'Preview this article'
      request.url.should == "http://#{@site.host}/articles/the-article-title-de?cl=de"
    end

    def delete_article
      visit @back_url
      click_link 'Delete this article'
      request.url.should =~ %r(/admin/sites/\d+/sections/\d+/articles)
      response.body.should_not =~ %r(the revised article title)
    end
  end
end