module IconHelper
  def icon(name, class_name: "icon")
    path = Rails.root.join("app/assets/images/icons/#{name}.svg")
    return "" unless File.exist?(path)

    svg = File.read(path)
    svg.sub("<svg", %(<svg class="#{ERB::Util.html_escape(class_name)}"))
       .html_safe
  end

  def icon_comment
    icon("comment", class_name: "icon icon--comment")
  end

  def icon_like(filled: false)
    icon(filled ? "heart_filled" : "heart", class_name: "icon icon--like")
  end

  def icon_bookmark(filled: false)
    icon(filled ? "bookmark_filled" : "bookmark", class_name: "icon icon--bookmark")
  end

  def icon_verified
    icon("verified", class_name: "icon icon--verified")
  end

  def icon_plus
    icon("plus", class_name: "icon icon--plus")
  end
end