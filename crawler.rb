require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'phone'
require 'csv'
require 'pry'

class Crawler
  URL_0 = 'http://www.jogging-plus.com/calendrier/marathons/france/'.freeze
  URL_1 = 'http://www.jogging-plus.com/calendrier/semi-marathons/france'.freeze
  HEADERS = [
    'date of event',
    'finishers number',
    'ville de depart',
    'email',
    'tel',
    'link',
    'distance'
  ].freeze

  attr_reader :data, :web_page, :metadata, :filename, :type

  def initialize(args = {})
    @data = {
      links:     [],
      emails:    [],
      phones:    [],
      finishers: [],
      departure: []
    }
    @type = args[:type] || :marathon
    @filename = "parsed_#{type}.csv"
  end

  def crawl
    prepare_csv

    download_page(marathon_type_url)

    data[:dates] = dates
    data[:names] = names
    data[:distance] = distance
    get_more_info

    write_csv
  end

  private

  def marathon_type_url
    return URL_0 if type.equal? :marathon
    URL_1 if type.equal? :semi_marathon
  end

  def tr_elements
    web_page.xpath('//tr')
  end

  def dates
    dates = tr_elements.reduce([]) do |memo, element|
      date, = element.xpath('./td')
      memo << date.text
      memo
    end
    dates.delete('Aucune épreuve trouvée')
    dates[0..-3]
  end

  def a_elements
    web_page.xpath('//tr/td/a/text()')
  end

  def names
    a_elements.reduce([]) do |memo, element|
      memo << element.text
      memo
    end
  end

  def distance_elements
    web_page.xpath('//em')
  end

  def distance
    distance_elements.reduce([]) do |memo, el|
      content = el.text
      memo << content if content.include?('Marathon') || content.include?('km') || content.include?('Semi')
      memo
    end
  end

  def url_elements
    web_page.xpath('//tr/td/a')
  end

  def get_more_info
    url_elements.each do |element|
      info(element)
    end
  end

  def info(element)
    download_page(element['href'])

    @metadata = web_page.xpath('//*[@id="bloc-gauche3"]')

    data[:finishers] << finishers
    data[:departure] << departure
    data[:links]     << link

    tmp_emails = emails
    data[:emails] << (tmp_emails.length.zero? ? 'no data' : tmp_emails)
    tmp_phones = phones
    data[:phones] << (tmp_phones.length.zero? ? 'no data' : tmp_phones)
  end

  def emails
    metadata.text.split.reduce([]) do |memo, element|
      memo << element[0..-2] if element.include? '@'
      memo
    end
  end

  def phones
    metadata.text.split('//').reduce([]) do |memo, element|
      Phoner::Phone.default_country_code = '33'
      Phoner::Phone.default_area_code = '0'
      pn = Phoner::Phone.parse(element)
      memo << (pn.nil? ? 'no data' : pn.format(:europe))
      memo
    end
  end

  def finishers
    _, second_div = web_page.xpath('//*[@id="bloc-info-label"]')
    return 'no data' unless second_div
    n_finishers = second_div.text
    n_finishers.include?('finishers') ? n_finishers : 'no data'
  end

  def departure
    departure_nodes = web_page.xpath('//*[@id="bloc-info-valeur"]')
    departure_nodes.text
  end

  def link
    link = web_page.xpath('//*[@id="bloc-gauche3"]/a')
    link.length == 1 ? link[0]['href'] : 'no data'
  end

  def download_page(url)
    html_data = open(url).read
    @web_page = Nokogiri::HTML(html_data)
  end

  def prepare_csv
    CSV.open(filename, 'ab') do |csv|
      csv << HEADERS
    end
  end

  def write_csv
    (0..data[:dates].length - 1).each do |i|
      dt = []
      dt << data[:dates][i]
      dt << data[:finishers][i]
      dt << data[:departure][i]
      emails = data[:emails]
      dt << (emails[i].length > 1 ? emails[i].join('/') : emails[i][0])
      phones = data[:phones]
      dt << (phones[i].length > 1 ? phones[i].join('/') : phones[i][0])
      dt << data[:links][i]
      dt << data[:distance][i]

      CSV.open(filename, 'ab') do |csv|
        csv << dt
      end
    end
  end
end

%i[marathon semi_marathon].each do |el|
  Crawler.new(type: el).crawl
end
