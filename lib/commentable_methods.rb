require 'active_record'

module ActsAsCommentable

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def acts_as_commentable(options={})
      has_many :comments, {:as => :commentable, :dependent => :destroy}.merge(options)
      include ActsAsCommentable::InstanceMethods
      extend ActsAsCommentable::SingletonMethods
    end
  end

  # This module contains class methods
  module SingletonMethods
    # Helper method to lookup for comments for a given object.
    # This method is equivalent to obj.comments.
    def find_comments_for(obj)
      commentable = ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s

      Comment.where("commentable_id = ? and commentable_type = ? and published = true", obj.id, commentable).
          order("created_at DESC")
    end

    # Helper class method to lookup comments for
    # the mixin commentable type written by a given user.
    # This method is NOT equivalent to Comment.find_comments_for_user
    def find_comments_by_user(user)
      commentable = ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s

      Comment.where("user_id = ? and commentable_type = ? and published = true", user.id, commentable).
          order("created_at DESC")
    end
  end

  # This module contains instance methods
  module InstanceMethods
    # Helper method to sort comments by date
    def comments_ordered_by_submitted
      Comment.where("commentable_id = ? and commentable_type = ? and published = true", id, self.class.name).
        order("created_at DESC")
    end

    # Helper method that defaults the submitted time.
    def add_comment(comment)
      if self.respond_to?(:moderated_comments) && self.moderated_comments
        comment.published = false
        comment.save
      end
      comments << comment
    end

    def dropbox_comments
      self.respond_to?(:dropbox_comments) && self.dropbox_comments
    end

    # Only get the comments visible to the user
    def visible_comments(user, params)
      params.reverse_merge!({:order => 'DESC', :page => 1, :per_page => 10, :limit => 10})
      # this only makes sense for moderated comments
      if user && self.respond_to?(:moderated_comments) && self.moderated_comments
        if (self.respond_to?(:owner) && self.owner == user) || (self.respond_to?(:comment_moderator?) && self.comment_moderator?(user)) || user.admin?
          return comments.order(params[:order]).limit(params[:limit]).paginate(:page => params[:page], :per_page => params[:per_page])
        else
          if self.moderated_comments == 1
            return comments.published_or_owned(user).order(params[:order]).limit(params[:limit]).paginate(:page => params[:page], :per_page => params[:per_page])
          else
            return comments.limit(0)
          end
        end
      end
      return comments.published..order(params[:order]).limit(params[:limit]).paginate(:page => params[:page], :per_page => params[:per_page])
    end

  end

end

ActiveRecord::Base.send(:include, ActsAsCommentable)
