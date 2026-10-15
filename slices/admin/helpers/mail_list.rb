# frozen_string_literal: true

module Admin
  module Helpers
    module MailList
      LABEL = "label:"
      UNREAD = Blog::Types::MailShow["unread"]

      module_function

      def anchor(id) = "read-#{id}"

      def back(routes, list, thread: nil, **query)
        path = routes.path(:admin_mail, **list, **query, **({ thread: } if thread))

        thread ? "#{path}##{anchor(thread)}" : path
      end

      def folder(value)
        text = Blog::Types::OptionalText[value]
        text&.start_with?(LABEL) && text != LABEL ? text : Blog::Types::MailFolderParam[text]
      end

      def from(params)
        {
          account: Blog::Types::IdParam[params[:account]],
          folder: folder(params[:folder]),
          show: Blog::Types::MailShowParam[params[:show]],
          search: Blog::Types::OptionalText[params[:search]],
        }.compact.merge(Blog::Structs::Page.query(Blog::Types::PageParam.call(params[:page]) { 1 }))
      end

      def label(folder) = (folder.delete_prefix(LABEL) if folder.start_with?(LABEL))

      def query(list)
        folder = list[:folder]

        { folder:, label: label(folder), account: list[:account], unread: list[:show] == UNREAD, search: list[:search] }
      end
    end
  end
end
