<?php
namespace Transvision;

// rtl support
$rtl = array('ar', 'fa', 'he');
$direction1 = (in_array($sourceLocale, $rtl)) ? 'rtl' : 'ltr';
$direction2 = (in_array($locale, $rtl)) ? 'rtl' : 'ltr';
$direction3 = (in_array($locale2, $rtl)) ? 'rtl' : 'ltr';


// Get cached bugzilla components (languages list) or connect to Bugzilla API to retrieve them
$bugzillaComponent = rawurlencode(
    Bugzilla::collectLanguageComponent(
        $locale,
        Bugzilla::getBugzillaComponents()
    )
);

$bugzillaLink = 'https://bugzilla.mozilla.org/enter_bug.cgi?format=__default__&component='
               . $bugzillaComponent
               . '&product=Mozilla%20Localizations&status_whiteboard=%5Btransvision-feedback%5D';

if ($locale == $locale2) {
    $table = "<table>
                <tr>
                    <th>Entity</th>\n
                    <th>" . $sourceLocale . "</th>
                    <th>" . $locale . "</th>
                </tr>";
} else {
    $table = "<table>
                <tr>
                    <th>Entity</th>\n
                    <th>" . $sourceLocale . "</th>
                    <th>" . $locale . "</th>
                    <th>" . $locale2 . "</th>
                </tr>";
}

foreach ($entities as $val) {

    $path_locale1 = VersionControl::filePath($sourceLocale, $check['repo'], $val);
    $path_locale2 = VersionControl::filePath($locale, $check['repo'], $val);
    $path_locale3 = VersionControl::filePath($locale2, $check['repo'], $val);

    if (isset($tmx_target[$val])) {
        // nbsp highlight
        $targetString = str_replace(' ', '<span class="highlight-gray"> </span>', $tmx_target[$val]);
    } else {
        $targetString = '';
    }
<<<<<<< HEAD

    $sourceString = $tmx_source[$val];

    // Link to entity
    $entityLink = "?sourcelocale={$sourceLocale}"
                 . "&locale={$locale}"
                 . "&repo={$check['repo']}"
                 . "&search_type=entities&recherche={$val}";

    $bugSummary = rawurlencode("Translation update proposed for {$val}");
    $bugMessage = rawurlencode(
        html_entity_decode(
            "The string:\n{$sourceString}\n\n"
            . "Is translated as:\n{$targetString}\n\n"
            . "And should be:\n\n\n\n"
            . "Feedback via Transvision:\n"
            . "http://transvision.mozfr.org/{$entityLink}"
        )
    );

    $complete_link = $bugzillaLink . '&short_desc=' . $bugSummary . '&comment=' . $bugMessage;

    $table .= "<tr>
                    <td>" . ShowResults::formatEntity($val, $my_search) . "</a></td>
                    <td dir='{$direction1}'>
                       <div class='string'>{$sourceString}</div>
                       <div class='infos'>
                        <a class='source_link' href='{$path_locale1}'><em>&lt;source&gt;</em></a>
                       </div>
                    </td>
                     <td dir='{$direction2}'>
                       <div class='string'>{$targetString}</div>
                       <div class='infos'>
                        <a class='source_link' href='{$path_locale2}'><em>&lt;source&gt;</em></a>
                        <a class='bug_link' target='_blank' href='{$complete_link}'>
                        &lt;report a bug&gt;
                      </a>
                       </div>
                    </td>
                </tr>";
=======
    if (isset($tmx_target2[$val])) {
        // nbsp highlight
        $target_string2 = str_replace(' ', '<span class="highlight-gray"> </span>', $tmx_target2[$val]);
    } else {
        $target_string2 = '';
    }

    if ($locale == $locale2) {
        $table .= "<tr>
                        <td>" . ShowResults::formatEntity($val, $my_search) . "</a></td>
                    <td dir='${direction1}'>
                            <div class='string'>" . $tmx_source[$val] . "</div>
                            <div class='sourcelink'><a href='${path_locale1}'><em>&lt;source&gt;</em></a></div>
                        </td>
                            <td dir='${direction2}'>
                            <div class='string'>${target_string}</div>
                        <div class='sourcelink'><a href='${path_locale2}'><em>&lt;source&gt;</em></a></div>
                        </td>
                 </tr>";
    } else {
        $table .= "<tr>
                        <td>" . ShowResults::formatEntity($val, $my_search) . "</a></td>
                    <td dir='${direction1}'>
                            <div class='string'>" . $tmx_source[$val] . "</div>
                            <div class='sourcelink'><a href='${path_locale1}'><em>&lt;source&gt;</em></a></div>
                        </td>
                            <td dir='${direction2}'>
                            <div class='string'>${target_string}</div>
                        <div class='sourcelink'><a href='${path_locale2}'><em>&lt;source&gt;</em></a></div>
                        </td>
                            <td dir='${direction3}'>
                            <div class='string'>${target_string2}</div>
                        <div class='sourcelink'><a href='${path_locale3}'><em>&lt;source&gt;</em></a></div>
                        </td>
                 </tr>";
    }

>>>>>>> d5e86a8dd5c6b07747afbe37ded227117f8f9898
}

$table .= "  </table>\n\n";

echo $table;
