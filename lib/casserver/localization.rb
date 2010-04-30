require 'i18n'
# tell the I18n library where to find your translations
I18n.load_path << Dir[ File.expand_path(File.join($APP_ROOT, 'config', 'locale', '*.yml')) ]
($CONF.i18n_files || []).each do |path|
  I18n.load_path << Dir[path]
end
# set default locale to something other than :en
I18n.default_locale = $CONF[:default_locale]

# module I18n
#   class << self
#     def available_locales; backend.available_locales; end
#   end
#   module Backend
#     class Simple
#       def available_locales
#         translations.keys.collect { |l| l.to_s }.sort
#       end
#     end
#   end
# end

# You need to "force-initialize" loaded locales
I18n.backend.send(:init_translations)

module CASServer
  
  AVAILABLE_LOCALES = I18n.backend.available_locales
  $LOG.debug "* Loaded #{I18n.backend} locales: #{AVAILABLE_LOCALES.inspect}"
  def available_locales; AVAILABLE_LOCALES; end
  
  def service(*a)
    r = super(*a)
    I18n.locale = determine_locale
    r
  end
  
  def determine_locale
  
    source = nil
    locale = case
    when !input['locale'].blank?
      source = "'locale' request variable"
      cookies['locale'] = input['locale']
      input['locale']
    when !cookies['locale'].blank?
      source = "'locale' cookie"
      cookies['locale']
    when !@env['HTTP_ACCEPT_LANGUAGE'].blank?
      source = "'HTTP_ACCEPT_LANGUAGE' header"
      locale = @env['HTTP_ACCEPT_LANGUAGE']
    when !@env['HTTP_USER_AGENT'].blank? && @env['HTTP_USER_AGENT'] =~ /[^a-z]([a-z]{2}(-[a-z]{2})?)[^a-z]/i
      source = "'HTTP_USER_AGENT' header"
      $~[1]
    when !$CONF['default_locale'].blank?
      source = "'default_locale' config option"
      $CONF[:default_locale]
    else
      source = "default"
      "en"
    end
  
    $LOG.debug "Detected locale is #{locale.inspect} (from #{source})"
    locale = locale.to_s
    locale.gsub!('_','-')
  
    # TODO: Need to confirm that this method of splitting the accepted
    #       language string is correct.
    if locale =~ /[,;\|]/
      locales = locale.split(/[,;\|]/)
    else
      locales = [locale]
    end
  
    # TODO: This method of selecting the desired language might not be
    #       standards-compliant. For example, http://www.w3.org/TR/ltli/
    #       suggests that de-de and de-*-DE might be acceptable identifiers
    #       for selecting various wildcards. The algorithm below does not
    #       currently support anything like this.  
    # Try to pick a locale exactly matching the desired identifier, otherwise
    # fall back to locale without region (i.e. given "en-US; de-DE", we would
    # first look for "en-US", then "en", then "de-DE", then "de").
    chosen_locale = nil
    locales.each do |l|
      break if chosen_locale = available_locales.find{|a| Regexp.new("\\A#{l}\\Z").match(a.to_s) || Regexp.new("#{l}-\w*").match(a.to_s)}
    end  
    chosen_locale ||= "en"  
    $LOG.debug "Chosen locale is #{chosen_locale.inspect}"  
    return chosen_locale
  end
  
end
