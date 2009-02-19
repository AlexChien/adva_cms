require_dependency 'site'

class Section < ActiveRecord::Base
=begin
  class Jail < Safemode::Jail
    allow :id, :type, :categories, :tag_counts
  end
=end

  @@types = ['Section']
  cattr_reader :types
  
  acts_as_role_context :actions => ["create article", "update article", "delete article"],
                       :parent => Site
  
  serialize :permissions

  has_option :articles_per_page, :default => 15
  has_option :template, :layout
  
  has_permalink :title, :url_attribute => :permalink, :sync_url => true, :only_when_blank => true, :scope => :site_id
  has_many_comments
  acts_as_nested_set
  instantiates_with_sti

  belongs_to :site
  has_many :articles, :foreign_key => 'section_id', :dependent => :destroy do
    def primary
      find_published :first, :order => :position
    end

    def permalinks
      find_published(:all).map(&:permalink)
    end
  end

  has_many :categories, :dependent => :destroy, :order => 'lft' do
    def roots
      find :all, :conditions => {:parent_id => nil}, :order => 'lft'
    end
  end

  before_validation :set_comment_age
  before_save :update_path

  validates_presence_of :title # :site wtf ... this breaks install_controller#index
  validates_uniqueness_of :permalink, :scope => :site_id
  validates_numericality_of :articles_per_page, :only_integer => true, :message => :only_integer
  
  # validates_each :template, :layout do |record, attr, value|
  #   record.errors.add attr, 'may not contain dots' if value.index('.') # FIXME i18n
  #   record.errors.add attr, 'may not start with a slahs' if value.index('.') # FIXME i18n
  # end

  # TODO validates_inclusion_of :articles_per_page, :in => 1..30, :message => "can only be between 1 and 30."

  delegate :spam_engine, :to => :site

  class << self
    def register_type(type)
      @@types << type
      @@types.uniq!
    end
    
    def content_type
      'Article'
    end
  end

  def owner
    site
  end

  def type
    read_attribute(:type) || 'Section'
  end

  def tag_counts
    Content.tag_counts :conditions => "section_id = #{id}"
  end

  def root_section?
    self == site.sections.root
  end

  def accept_comments?
    comment_age.to_i > -1
  end
  
  # Template and layout can be specified as full template names like "sections/home"
  # and 'layouts/simple'. Both can also use * as a wildchard for the current action
  # name. E.g. "sections/*" will become "sections/show" when the current action is
  # :show. The template/" and "layout/" (for layout) subdirectories can be given or
  # omitted, thus "templates/sections/home" and "sections/home" are identical.
  def template_options(action)
    @template_options ||= {}
    @template_options[action] ||= [:layout, :template].inject({}) do |options, type|
      option = template_option(type, action)
      options[type] = option unless option.blank?
      options
    end
  end

  protected

    def template_option(type, action)
      return unless option = send(type)
      option.sub!(/(\*)$/, action.to_s)
      option.sub!(/^templates\//, '')
      option.sub!(/^(?!layouts)/, 'layouts/') if type == :layout and !option.blank?
      option
    end

    def set_comment_age
      self.comment_age ||= -1
    end

    def update_path
      if permalink_changed?
        new_path = build_path
        unless self.path == new_path
          self.path = new_path
          @paths_dirty = true
        end
      end
    end

    def build_path
      self_and_ancestors.map(&:permalink).join('/')
    end
end
