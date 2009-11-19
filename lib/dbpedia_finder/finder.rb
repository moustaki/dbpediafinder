require 'rubygems'
require '4store-ruby'
require 'uri'
require 'json'
require 'net/http'

module DbpediaFinder

  class Finder

    def initialize
      @store = FourStore::Store.new 'http://dbpedia.org/sparql'
      @proxy = URI.parse(ENV['HTTP_PROXY']) if ENV['HTTP_PROXY']
    end

    def find(label, disambiguation = nil)
      results = google_search(label, disambiguation)
      results.each do |uri|
        dbpedia = wikipedia_to_dbpedia(uri)
        query = "
          PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
          SELECT DISTINCT ?label WHERE {
            <#{dbpedia}> rdfs:label ?label
            FILTER (
              regex(?label, '#{clean_label(label)}', 'i')
            )
          }
        "
        match = @store.select query
        return [match[0]['label'], uri] if match.size > 0
      end
      return nil
    end

    def google_search(label, disambiguation)
      if disambiguation
        query = "\"#{label}\" #{disambiguation} site:en.wikipedia.org"
      else
        query = "\"#{label}\" site:en.wikipedia.org"
      end
      query = URI.encode(query)
      google_url_s = "http://ajax.googleapis.com/ajax/services/search/web?v=1.0&q=#{query}"
      url = URI.parse(google_url_s)
      if @proxy
        h = Net::HTTP::Proxy(@proxy.host, @proxy.port).new(url.host, url.port)
      else
        h = Net::HTTP.new(url.host, url.port)
      end
      h.start do |h|
        res = h.get(url.path + "?" + url.query)
        json = JSON.parse(res.body)
        results = json["responseData"]["results"].map { |result| result["url"] }
        return results
      end
    end

    def wikipedia_to_dbpedia(wikipedia)
      url_key = wikipedia.split('/').last
      return "http://dbpedia.org/resource/" + url_key
    end

    def clean_label(label)
      # Remove initials (as they are expanded in Wikipedia/DBpedia labels)
      cleaned_label = label.split(' ').select { |l| l.split('.').size == 1 }.join(' ')
      cleaned_label = cleaned_label.split("'").join("\\'")
      cleaned_label
    end

  end

end
