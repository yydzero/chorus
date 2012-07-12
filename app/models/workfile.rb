class Workfile < ActiveRecord::Base
  include SoftDelete

  attr_accessible :description, :file_name

  belongs_to :workspace
  belongs_to :owner, :class_name => 'User'

  has_many :versions, :class_name => 'WorkfileVersion'
  has_many :drafts, :class_name => 'WorkfileDraft'
  has_many :activities, :as => :entity
  has_many :events, :through => :activities

  validates_format_of :file_name, :with => /^[a-zA-Z0-9_ \.\(\)\-]+$/

  attr_accessor :highlighted_attributes, :search_result_comments
  searchable do
    text :file_name, :stored => true, :boost => SOLR_PRIMARY_FIELD_BOOST
    text :description, :stored => true, :boost => SOLR_SECONDARY_FIELD_BOOST
    integer :workspace_id
    integer :member_ids, :multiple => true
    boolean :public
    string :grouping_id
    string :type_name
  end

  def self.search_permissions(current_user, search)
    unless current_user.admin?
      search.build do
        any_of do
          without :type_name, Workfile.type_name
          with :member_ids, current_user.id
          with :public, true
        end
      end
    end
  end

  def self.by_type(file_type)
    scoped.find_all { |workfile| workfile.versions.last.file_type == file_type.downcase }
  end

  def create_new_version(user, source_file, message)
    versions.create!(
      :owner => user,
      :modifier => user,
      :contents => source_file,
      :version_num => last_version_number + 1,
      :commit_message => message,
    )
  end

  def last_version
    versions.order("version_num").last
  end

  def has_draft(current_user)
    !!WorkfileDraft.find_by_owner_id_and_workfile_id(current_user.id, id)
  end

  def copy(user, workspace)
    workfile = Workfile.new
    workfile.file_name = file_name
    workfile.description = description
    workfile.workspace = workspace
    workfile.owner = user

    workfile
  end

  def member_ids
    workspace.member_ids
  end

  def public
    workspace.public
  end

  private
  def last_version_number
    last_version.try(:version_num) || 0
  end
end