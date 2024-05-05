import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "lyrics.js" as Json_lyrics
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property int config_flush_time: Plasmoid.configuration.flush_time
    readonly property int config_time_offset: Plasmoid.configuration.time_offset
    readonly property string config_text_color: Plasmoid.configuration.text_color
    readonly property string config_text_font: Plasmoid.configuration.text_font
    readonly property string cfg_first_language: Plasmoid.configuration.first_language
    readonly property string cfg_second_language: Plasmoid.configuration.second_language
    readonly property string cfg_show_title: Plasmoid.configuration.show_title

    compactRepresentation: fullRepresentation
    preferredRepresentation: Plasmoid.fullRepresentation

    fullRepresentation: Item {
        property string lyric_original_cache: ''
        property string lyric_translated_cache: ''
        property string lyric_romaji_cache: ''
        property int id_original_cache: 0
        property int id_translated_cache: 0
        property int id_romaji_cache: 0
        property bool valid_original_cache: false
        property bool valid_translated_cache: false
        property bool valid_romaji_cache: false
        property bool no_translated_cache: false
        property bool no_romaji_cache: false
        property int timeout_count: 0

        property string title: ''
        property string artist: ''

        function get_lyric() {
            var xhr = new XMLHttpRequest();
            xhr.open('GET', 'http://127.0.0.1:27232/player', false);
            xhr.send(null);
            if (200 == xhr.status) {
                var tracker = getMeta(xhr.responseText);
                if (tracker.id == -1)
                    return ;

                timeout_count = 0;
                select_lyric(tracker);

                title = tracker.name;
                artist = tracker.artist;
            } else {
                if (timeout_count < 5)
                    timeout_count++;

                if (timeout_count >= 5) {
                    lyric_line.text = "";
                    id_original_cache = 0;
                    id_translated_cache = 0;
                    id_romaji_cache = 0;
                }
            }
        }

        function get_lyric_by_time(lyrics, time) {
            if (!lyrics || lyrics == '\\\\')
                return '';

            var lyric_obj = new Lyrics(lyrics);
            if (!lyric_obj) return '';
            var last_time = 0;
            var last_text = "";
            var flag = false;
            var real_time = time + config_time_offset / 1000;
            var target_line = "";
            if (real_time < 0 || real_time < lyric_obj.lyrics_all[0].timestamp)
                real_time = lyric_obj.lyrics_all[0].timestamp;

            for (var i = 0; i < lyric_obj.length; i++) {
                if ((last_time <= real_time) && (real_time < lyric_obj.lyrics_all[i].timestamp)) {
                    target_line = last_text;
                    flag = true;
                }
                last_time = lyric_obj.lyrics_all[i].timestamp;
                last_text = lyric_obj.lyrics_all[i].text;
                if (flag)
                    break;

            }
            if (!flag)
                return last_text;
            else
                return target_line;
        }

        function select_lyric(tracker) {
            if (tracker.id != id_original_cache) {
                lyric_original_cache = "";
                id_original_cache = -1;
                valid_original_cache = false;
            }
            if (tracker.id != id_translated_cache) {
                lyric_translated_cache = "";
                id_translated_cache = -1;
                valid_translated_cache = false;
            }
            if (tracker.id != id_romaji_cache) {
                lyric_romaji_cache = "";
                id_romaji_cache = -1;
                valid_romaji_cache = false;
            }
            if (!valid_original_cache || (!valid_translated_cache && !no_translated_cache) || (!valid_romaji_cache && !no_romaji_cache)) {
                var xhr = new XMLHttpRequest();
                xhr.open('GET', 'http://127.0.0.1:10754/lyric?id=' + tracker.id);
                xhr.send();
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4 || xhr.status === 200) {
                        var raw_json = xhr.responseText;
                        var lyrics = extract_lyrics(raw_json);
                        if (lyrics.translated && lyrics.translated === '\\\\')
                            lyrics.translated = null;

                        if (lyrics.romaji && lyrics.romaji === '\\\\')
                            lyrics.romaji = null;

                        if (lyrics && lyrics.original !== null) {
                            lyric_original_cache = lyrics.original;
                            id_original_cache = tracker.id;
                            valid_original_cache = true;
                        }
                        if (lyrics && lyrics.translated !== null) {
                            lyric_translated_cache = lyrics.translated;
                            id_translated_cache = tracker.id;
                            valid_translated_cache = true;
                        } else if (valid_original_cache) {
                            no_translated_cache = true;
                        }
                        if (lyrics && lyrics.romaji !== null) {
                            lyric_romaji_cache = lyrics.romaji;
                            id_romaji_cache = tracker.id;
                            valid_romaji_cache = true;
                        } else if (valid_original_cache) {
                            no_romaji_cache = true;
                        }
                    }
                };
            }
            if (valid_original_cache) {
                // select original tor other types
                var target_lyrics = "";
                var target_type = "";
                var second_lyrics = "";
                var second_type = "";
                if (cfg_first_language === "romaji" && valid_romaji_cache) {
                    target_lyrics = lyric_romaji_cache;
                    target_type = "romaji";
                } else if (cfg_first_language === "translated" && valid_translated_cache) {
                    target_lyrics = lyric_translated_cache;
                    target_type = "translated";
                } else {
                    target_lyrics = lyric_original_cache;
                    target_type = "original";
                }
                if (cfg_second_language === "romaji" && valid_romaji_cache) {
                    second_lyrics = lyric_romaji_cache;
                    second_type = "romaji";
                } else if (cfg_second_language === "translated" && valid_translated_cache) {
                    second_lyrics = lyric_translated_cache;
                    second_type = "translated";
                } else if (cfg_second_language === "original") {
                    second_lyrics = lyric_original_cache;
                    second_type = "original";
                } else {
                    second_type = target_type;
                }
                var ret_lyric = get_lyric_by_time(target_lyrics, tracker.progress);
                if (ret_lyric === "" || ret_lyric === null || ret_lyric === undefined) {
                    valid_original_cache = false;
                    valid_translated_cache = false;
                    valid_romaji_cache = false;
                }
                var line = trimLyricLine(ret_lyric);
                if (cfg_second_language != "disable" && second_type != target_type) {
                    var second_lyric = get_lyric_by_time(second_lyrics, tracker.progress);
                    line = line + "  " + trimLyricLine(second_lyric);
                }

                if(cfg_show_title === 'yes') {
                    line += ` | ${artist} - ${title}`;
                }

                lyric_line.text = line;
            }
        }

        function extract_lyrics(raw_json) {
            raw_json = raw_json || '';
            raw_json = raw_json//.replace(/\//g, '\\\/')
                                //.replace(/\n/g, '\\n')
                                //.replace(/\'/g, '\\\'')
                                //.replace(/\"/g, '\\\"');
            try {
                var j = JSON.parse(raw_json);
            }
            catch(e) {

            }
            
            try {
                return {
                    "original": (j.lrc && j.lrc.version > 0) ? j.lrc.lyric : null,
                    "translated": (j.tlyric && j.tlyric.version > 0) ? j.tlyric.lyric : null,
                    "romaji": (j.romalrc && j.romalrc.version > 0) ? j.romalrc.lyric : null
                };
            } catch (e) {
                return {
                    "original": null,
                    "translated": null,
                    "romaji": null
                };
            }
        }

        function getMeta(ypm_res) {
            if (!(ypm_res == undefined || ypm_res == null || ypm_res == '')) {
                var obj = JSON.parse(ypm_res);
                return {
                    "id": obj.currentTrack.id,
                    "progress": obj.progress,
                    "name": obj.currentTrack.name,
                    "artist": `${obj.currentTrack.ar.map(ar => ar.name).slice(0, 3).join('/')}${obj.currentTrack.ar.length > 3 ? '/...' : ''}`,
                };
            } else {
                return {
                    "id": -1,
                    "progress": 0,
                    "name": '',
                    "artist": '',
                };
            }
        }

        function trimLyricLine(line) {
            return line.replace(/【|】|〗|〖/g, '');
        }

        Layout.preferredWidth: lyric_line.implicitWidth
        Layout.preferredHeight: lyric_line.implicitWidth

        Label {
            id: lyric_line

            text: ""
            color: config_text_color
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            font: config_text_font || theme.defaultFont
        }

        Timer {
            interval: config_flush_time
            running: true
            repeat: true
            onTriggered: get_lyric()
        }

    }

}
