export class Lesson {
  title: string;
  author: string;
  category: i32;
  level: i32;
  keySignature: string;
  numerator: i32;
  denominator: i32;
  tempo: i32;
  notes: i32[];
  fingers: i32[];
  beats: f32[];
  guide: i32[];
  guideFingers: i32[];
  source: string;

  constructor(title: string, author: string, category: i32, level: i32,
    keySignature: string, numerator: i32, denominator: i32, tempo: i32,
    notes: i32[], fingers: i32[], beats: f32[], guide: i32[], guideFingers: i32[], source: string) {
    this.title = title;
    this.author = author;
    this.category = category;
    this.level = level;
    this.keySignature = keySignature;
    this.numerator = numerator;
    this.denominator = denominator;
    this.tempo = tempo;
    this.notes = notes;
    this.fingers = fingers;
    this.beats = beats;
    this.guide = guide;
    this.guideFingers = guideFingers;
    this.source = source;
    assert(notes.length > 0 && notes.length == fingers.length && notes.length == beats.length, title);
    assert(category >= 1 && category <= 3 && tempo >= 40 && tempo <= 160, title);
    assert(numerator > 0 && denominator > 0 && guide.length == guideFingers.length, title);
    const deriveGuide = guide.length == 0;
    for (let i = 0; i < notes.length; i++) {
      assert(notes[i] >= 48 && notes[i] <= 89 && fingers[i] >= 1 && fingers[i] <= 5, title);
      assert(isFinite(beats[i]) && beats[i] > 0, title);
      if (deriveGuide && guide.indexOf(notes[i]) < 0) {
        guide.push(notes[i]);
        guideFingers.push(fingers[i]);
      }
    }
  }
}

const MUTOPIA: string = "https://github.com/MutopiaProject/MutopiaProject/blob/master/ftp/";

export const CATALOG: Lesson[] = [
  new Lesson("Fur Elise", "Ludwig van Beethoven", 3, 2, "A minor", 3, 8, 84,
    [76,75,76,75,76,71,74,72,69,60,64,69,71,64,68,71,72,64,76,75,76,75,76,71,74,72,69],
    [5,4,5,4,5,2,4,3,1,1,2,4,5,1,2,4,5,1,5,4,5,4,5,2,4,3,1],
    [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,1,0.5,0.5,0.5,1,0.5,0.5,0.5,1,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,1.5],
    [69,71,72,74,76], [1,2,3,4,5], "https://imslp.org/wiki/F%C3%BCr_Elise,_WoO_59_(Beethoven,_Ludwig_van)"),
  new Lesson("Five-finger flow", "An original Virtuoso exercise", 1, 1, "C major", 4, 4, 84,
    [65,64,62,64,65,64,62,64,67,65,64,62,65,67,69,67,65,64,62,64,65,64,62,62],
    [3,2,1,2,3,2,1,2,4,3,2,1,3,4,5,4,3,2,1,2,3,2,1,1],
    new Array<f32>(24).fill(1), [62,64,65,67,69], [1,2,3,4,5], "Original Virtuoso exercise"),
  new Lesson("C major climb", "The foundations, one note at a time", 1, 1, "C major", 4, 4, 72,
    [60,62,64,65,67,69,71,72,71,69,67,65,64,62,60],
    [1,2,3,1,2,3,4,5,4,3,2,1,3,2,1],
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,2],
    [60,62,64,65,67,69,71,72], [1,2,3,1,2,3,4,5], "Original Virtuoso scale exercise"),
  new Lesson("Amazing Grace", "Traditional / New Britain", 2, 1, "C major", 3, 4, 72,
    [67,72,76,72,76,74,72,69,67,67,72,76,72,76,74,76,79],
    [1,2,4,2,4,3,2,1,1,1,2,4,2,3,2,3,5],
    [1,2,0.5,0.5,2,1,2,1,2,1,2,0.5,0.5,2,0.5,0.5,3],
    [], [], "https://en.wikipedia.org/wiki/Amazing_Grace"),
  new Lesson("Brahms' Lullaby", "Johannes Brahms", 3, 1, "C major", 3, 4, 76,
    [64,64,67,64,64,67,64,67,72,71,69,69,67,62,64,65,62,62,64,65,62,65,71,69,67,71,72],
    [2,2,4,2,2,4,2,3,5,4,3,3,2,1,2,3,1,1,2,3,1,2,5,4,3,4,5],
    [0.5,0.5,1.5,0.5,1,2,0.5,0.5,1,1.5,0.5,1,1,0.5,0.5,1,1,0.5,0.5,2,0.5,0.5,0.5,0.5,1,1,2],
    [], [], MUTOPIA + "BrahmsJ/LullabyBrahms-C/LullabyBrahms-C.ly"),
  new Lesson("Frere Jacques", "Traditional French round", 2, 1, "F major", 4, 4, 88,
    [65,67,69,65,65,67,69,65,69,70,72,69,70,72,72,74,72,70,69,65,72,74,72,70,69,65,65,60,65,65,60,65],
    [1,2,3,1,1,2,3,1,3,4,5,3,4,5,4,5,4,3,2,1,4,5,4,3,2,1,5,1,5,5,1,5],
    [1,1,1,1,1,1,1,1,1,1,2,1,1,2,0.5,0.5,0.5,0.5,1,1,0.5,0.5,0.5,0.5,1,1,1,1,2,1,1,2],
    [], [], "https://en.wikipedia.org/wiki/Fr%C3%A8re_Jacques"),
  new Lesson("Ode to Joy", "Ludwig van Beethoven", 3, 1, "C major", 4, 4, 96,
    [64,64,65,67,67,65,64,62,60,60,62,64,64,62,62,64,64,65,67,67,65,64,62,60,60,62,64,62,60,60],
    [3,3,4,5,5,4,3,2,1,1,2,3,3,2,2,3,3,4,5,5,4,3,2,1,1,2,3,2,1,1],
    [1,1,1,1,1,1,1,1,1,1,1,1,1.5,0.5,2,1,1,1,1,1,1,1,1,1,1,1,1,1.5,0.5,2],
    [], [], "https://imslp.org/wiki/Symphony_No.9,_Op.125_(Beethoven,_Ludwig_van)"),
  new Lesson("Swan Lake Theme", "Pyotr Ilyich Tchaikovsky", 3, 2, "B minor", 4, 4, 72,
    [66,71,73,74,76,78,74,78,76,74,76,73,71,69,71],
    [1,2,3,1,2,3,1,3,2,1,3,2,1,1,2],
    [1,1.5,0.5,1,1,2,1,1,1.5,0.5,1,1,2,0.5,0.5],
    [], [], "https://imslp.org/wiki/Swan_Lake,_Op.20_(Tchaikovsky,_Pyotr)"),
  new Lesson("Happy Birthday to You", "Mildred and Patty Hill", 2, 1, "C major", 3, 4, 88,
    [67,67,69,67,72,71,67,67,69,67,74,72,67,67,79,76,72,71,69,77,77,76,72,74,72],
    [1,1,2,1,4,3,1,1,2,1,5,4,1,1,5,3,1,3,2,5,5,4,1,3,1],
    [0.75,0.25,1,1,1,2,0.75,0.25,1,1,1,2,0.75,0.25,1,1,1,1,1,0.75,0.25,1,1,1,2],
    [], [], "https://en.wikipedia.org/wiki/Happy_Birthday_to_You"),
  new Lesson("Clair de Lune", "Claude Debussy", 3, 3, "D flat major", 9, 8, 52,
    [68,80,77,75,77,75,73,75,73,77,73,72,73,72],
    [2,5,3,2,3,2,1,2,1,3,2,1,2,1],
    [0.5,2,2,0.5,0.5,3.5,0.5,0.5,0.75,1.5,1.25,0.5,0.5,3],
    [], [], MUTOPIA + "DebussyC/L75/debussy_Ste_Bergamesq_Clair/debussy_Ste_Bergamesq_Clair.ly"),
  new Lesson("Bach's Prelude No. 1 in C", "Johann Sebastian Bach", 3, 2, "C major", 4, 4, 64,
    [60,64,67,72,76,67,72,76,60,64,67,72,76,67,72,76,60,62,69,74,77,69,74,77,60,62,69,74,77,69,74,77],
    [1,2,3,1,3,1,2,3,1,2,3,1,3,1,2,3,1,2,3,1,3,1,2,3,1,2,3,1,3,1,2,3],
    new Array<f32>(32).fill(0.25), [], [], MUTOPIA + "BachJS/BWV846/wtk1-prelude1/wtk1-prelude1.ly"),
  new Lesson("Moonlight Sonata", "Ludwig van Beethoven", 3, 2, "C sharp minor", 2, 2, 60,
    [68,73,76,68,73,76,68,73,76,68,73,76,68,73,76,68,73,76,68,73,76,68,73,76],
    [1,3,5,1,3,5,1,3,5,1,3,5,1,3,5,1,3,5,1,3,5,1,3,5],
    new Array<f32>(24).fill(<f32>(1.0 / 3.0)), [], [], "https://imslp.org/wiki/Piano_Sonata_No.14,_Op.27_No.2_(Beethoven,_Ludwig_van)"),
  new Lesson("Prelude in E minor", "Frederic Chopin", 3, 2, "E minor", 2, 2, 60,
    [59,71,71,72,71,72,71,72,71,70,69,71,69,71],
    [1,4,2,3,2,3,2,3,2,2,1,2,1,2],
    [0.75,0.25,3,1,3,1,3,1,3,1,3,1,3,1],
    [], [], MUTOPIA + "ChopinFF/O28/Chop-28-4/Chop-28-4.ly"),
  new Lesson("Eine kleine Nachtmusik", "Wolfgang Amadeus Mozart", 3, 2, "G major", 4, 4, 104,
    [67,62,67,62,67,62,67,71,74,72,69,72,69,72,69,66,69,62],
    [3,1,3,1,3,1,2,3,5,4,2,4,2,4,2,1,3,1],
    [1.5,0.5,1.5,0.5,0.5,0.5,0.5,0.5,2,1.5,0.5,1.5,0.5,0.5,0.5,0.5,0.5,2],
    [], [], MUTOPIA + "MozartWA/KV525/eine-kleine-nachtmusik-mvt1/eine-kleine-nachtmusik-mvt1-lys/violin1.ly"),
  new Lesson("When the Saints Go Marching In", "Traditional gospel", 2, 1, "C major", 4, 4, 104,
    [60,64,65,67,60,64,65,67,60,64,65,67,64,60,64,62,64,64,62,60],
    [1,3,4,5,1,3,4,5,1,3,4,5,3,1,3,2,3,3,2,1],
    [1,1,1,5,1,1,1,5,1,1,1,2,2,2,2,5,1,1,1,5],
    [], [], "https://en.wikipedia.org/wiki/When_the_Saints_Go_Marching_In"),
  new Lesson("Greensleeves", "Traditional English melody", 2, 2, "E minor", 6, 8, 84,
    [64,67,69,71,72,71,69,66,62,64,66,67,64,64,63,64,66,59],
    [1,2,3,4,5,4,3,2,1,2,3,4,2,2,1,2,3,1],
    [0.5,1,0.5,0.75,0.25,0.5,1,0.5,0.75,0.25,0.5,1,0.5,0.75,0.25,0.5,1.5,1],
    [], [], MUTOPIA + "Traditional/greensleeves/greensleeves.ly"),
  new Lesson("Scarborough Fair", "Traditional / Kidson, 1891", 2, 1, "G major", 3, 4, 80,
    [62,67,67,67,69,71,72,74,74,69,71,71,71,72,71,69,67,67,64,62],
    [1,2,2,2,3,4,1,2,2,1,3,3,3,4,3,2,1,1,2,1],
    [1,1,1,1,1,1,1,2,1,3,1,1,1,1,1,1,1,1,1,2],
    [], [], "https://archive.org/details/imslp-tunes-kidson-frank/page/42/mode/2up"),
  new Lesson("Auld Lang Syne", "Traditional Scottish melody", 2, 1, "F major", 4, 4, 84,
    [60,65,65,65,69,67,65,67,69,65,65,69,72,74,74,72,69,69,65,67,65,67,69,65,62,62,60,65],
    [1,2,2,2,4,3,2,3,4,2,2,3,5,5,5,4,2,2,1,2,1,2,3,4,2,2,1,4],
    [1,1.5,0.5,1,1,1.5,0.5,1,1,1.5,0.5,1,1,3,1,1.5,0.5,1,1,1.5,0.5,1,1,1.5,0.5,1,1,3],
    [], [], "https://en.wikipedia.org/wiki/Auld_Lang_Syne"),
  new Lesson("Jingle Bells", "James Lord Pierpont", 2, 1, "C major", 4, 4, 112,
    [64,64,64,64,64,64,64,67,60,62,64,65,65,65,65,65,64,64,64,64,62,62,64,62,67],
    [3,3,3,3,3,3,3,5,1,2,3,4,4,4,4,4,3,3,3,3,2,2,3,2,5],
    [1,1,2,1,1,2,1,1,1.5,0.5,4,1,1,1.5,0.5,1,1,1,0.5,0.5,1,1,1,2,2],
    [], [], "https://en.wikipedia.org/wiki/Jingle_Bells"),
  new Lesson("The Entertainer", "Scott Joplin", 3, 3, "C major", 2, 4, 84,
    [62,63,64,72,64,72,64,72,72,74,75,76,72,74,76,71,74,72],
    [1,2,3,5,1,5,1,5,1,2,3,4,1,2,4,1,3,2],
    [0.25,0.25,0.25,0.5,0.25,0.5,0.25,1.5,0.25,0.25,0.25,0.25,0.25,0.25,0.5,0.25,0.5,1.5],
    [], [], MUTOPIA + "JoplinS/entertainer/entertainer.ly"),
  // BEGIN GENERATED MUTOPIA EXCERPTS
  // Regenerate with npm run import:mutopia -- --root /path/to/ftp
  // Public Domain; Mutopia typesetter: Steve Dunlop.
  // Soprano; transpose 0 semitones; source SHA-256 9c3826496117f17e3bd1768020371a93194796ef9f12041afb54ad7e37daa923
  new Lesson("The First Noel", "Traditional English carol", 2, 1, "D major", 3, 4, 80,
    [66,64,62,64,66,67,69,71,73,74,73,71,69,71,73,74,73,71,69,71,73,74,69,67,66],
    [3,2,1,2,3,4,5,1,2,3,2,1,3,4,5,5,4,3,2,3,4,5,2,1,3],
    [0.5,0.5,1.5,0.5,0.5,0.5,2,0.5,0.5,1,1,1,2,0.5,0.5,1,1,1,1,1,1,1,1,1,2],
    [], [], MUTOPIA + "Traditional/first_noel/first_noel.ly"),
  // Public Domain; Mutopia typesetter: Geoffrey Lehr.
  // soprano; transpose 0 semitones; source SHA-256 b5de0ee05f7d516cd7515b32acd24ed3e9e2a0e0cac7b87f540cb60abd8e8c08
  new Lesson("The Holly and the Ivy", "Traditional English carol", 2, 1, "F major", 3, 4, 88,
    [65,65,65,65,74,72,69,65,65,65,65,74,72,72,70,69,67,65,69,69,62,62,60,65,67,69,70,69,67,65],
    [1,1,1,1,5,4,2,1,1,1,1,5,4,4,3,3,2,1,3,3,2,2,1,3,4,5,5,4,3,1],
    [1,0.5,0.5,1,1,1,1.5,0.5,0.5,0.5,1,1,2,0.5,0.5,0.5,0.5,1,0.5,0.5,0.5,0.5,1,0.5,0.5,0.5,0.5,1,1,2],
    [], [], MUTOPIA + "Traditional/thehollyandtheivy/thehollyandtheivy.ly"),
  // Public Domain; Mutopia typesetter: Nigel Holmes.
  // melody; transpose 0 semitones; source SHA-256 e6e7dcf668ca21d3a2b71b333c35e7045b04bc68d18859bedcdfe657096e3144
  new Lesson("Oats and Beans", "Traditional / L. E. Broadwood", 2, 1, "C major", 6, 8, 96,
    [67,67,64,60,65,69,67,67,67,67,64,60,65,65,69,67,72,72,71,71,69,69,67,67,65,65,64,64,62,62,62,60],
    [4,4,3,1,3,5,4,4,4,4,3,1,3,3,5,4,5,5,4,4,3,3,2,2,4,4,3,3,2,2,2,1],
    [1,0.5,1,0.5,1,0.5,1,0.5,1,0.5,1,0.5,0.5,0.5,0.5,1.5,1,0.5,1,0.5,1,0.5,1,0.5,1,0.5,1,0.5,0.5,0.5,0.5,1.5],
    [], [], MUTOPIA + "Traditional/oatsandbeans/oatsandbeans.ly"),
  // Public Domain; Mutopia typesetter: Nigel Holmes.
  // melody; transpose 0 semitones; source SHA-256 76465fbe5e255d325a7ebe4d294e758455c4790572f6c2bf4e13bc590a13ac18
  new Lesson("The Water of Tyne", "Traditional / J. A. Fuller-Maitland", 2, 1, "D major", 6, 8, 80,
    [69,69,66,66,69,66,64,62,62,62,62,64,66,67,67,66,64,66,69,71,71,71,69,66,64],
    [5,5,3,3,5,3,2,1,1,1,1,2,3,4,4,3,2,3,5,4,4,4,3,2,1],
    [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.75,0.25,1,0.25,0.25,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.75,0.25,1,0.25,0.25],
    [], [], MUTOPIA + "Traditional/wateroftyne/wateroftyne.ly"),
  // Public Domain; Mutopia typesetter: Nigel Holmes.
  // melody; transpose 0 semitones; source SHA-256 3e053d043272823a8885b090fdc705c7cdd087d61889be6b08654eb346ac30ad
  new Lesson("John Barleycorn", "Traditional / Gustav Holst", 2, 2, "C major", 2, 4, 80,
    [64,69,69,74,74,72,71,69,69,71,72,72,74,74,69,69,74,74,72,71,69,67,67,69,69,69,69,67,69,62,64,65,67,69,71,69,67,65,64,64,62],
    [1,2,2,5,5,4,3,2,2,3,4,4,5,5,2,2,5,5,4,3,2,1,1,2,2,2,2,1,2,1,2,3,4,5,4,3,2,3,2,2,1],
    [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.25,0.25,0.5,0.5,0.5,0.5,1.5,0.5,0.5,0.5,0.5,0.25,0.25,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.375,0.125,0.25,0.25,0.5,0.25,0.25,1.5],
    [], [], MUTOPIA + "Traditional/johnbarleycorn/johnbarleycorn.ly"),
  // Public Domain; Mutopia typesetter: Taj Morton.
  // melody; transpose 0 semitones; source SHA-256 5029f09dd87132e91703e0096434fe18f1bde0bf234cd49f5ee9a59a28867973
  new Lesson("Soldier's Joy", "Traditional fiddle tune", 2, 2, "D major", 4, 4, 104,
    [66,67,69,66,62,66,69,66,62,66,69,74,74,73,71,69,66,62,66,69,66,62,66,67,64,64],
    [2,3,4,2,1,2,4,2,1,2,3,5,5,4,3,4,2,1,2,4,2,1,2,3,2,2],
    [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,1,1,1,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,1,1,1],
    [], [], MUTOPIA + "Traditional/soldiers-joy/soldiers-joy.ly"),
  // Public Domain; Mutopia typesetter: Allen Garvin.
  // voiceone; transpose 0 semitones; source SHA-256 b221377c045a053dbc495d940d7dec8b0c105c7db0a65bca11d6e21389369f97
  new Lesson("Minuet in F (Anh. 113)", "Anna Magdalena Bach notebook", 3, 2, "F major", 3, 4, 80,
    [72,74,76,77,76,77,76,74,72,74,75,74,72,74,72,70,72,70],
    [1,2,3,4,3,4,3,2,1,2,3,2,1,2,1,2,3,2],
    [1,0.25,0.25,0.5,1,0.333333333,0.333333333,0.333333333,2,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333],
    [], [], MUTOPIA + "BachJS/BWVAnh113/anna-magdalena-03/anna-magdalena-03.ly"),
  // Public Domain; Mutopia typesetter: Allen Garvin.
  // voiceone; transpose 0 semitones; source SHA-256 1a7932ea8ef8df96506a339a88189451bd18b66a9205264e09324e7ec0559d43
  new Lesson("Minuet in G (Anh. 114)", "Christian Petzold", 3, 1, "G major", 3, 4, 84,
    [74,67,69,71,72,74,67,67,76,72,74,76,78,79,67,67,72,74,72,71,69,71,72,71,69,67,66,67,69,71,67,69],
    [5,1,2,3,4,5,1,1,4,1,2,3,4,5,1,1,3,4,3,2,1,2,3,2,1,2,1,2,3,4,2,1],
    [1,0.5,0.5,0.5,0.5,1,1,1,1,0.5,0.5,0.5,0.5,1,1,1,1,0.5,0.5,0.5,0.5,1,0.5,0.5,0.5,0.5,1,0.5,0.5,0.5,0.5,3],
    [], [], MUTOPIA + "BachJS/BWVAnh114/anna-magdalena-04/anna-magdalena-04.ly"),
  // Public Domain; Mutopia typesetter: Allen Garvin.
  // voiceone; transpose 0 semitones; source SHA-256 711410e4af706979ca0b344b0ae4a23cb1592c1e4d799f4fad29ab06032adc5f
  new Lesson("Minuet in G minor", "Christian Petzold", 3, 2, "G minor", 3, 4, 76,
    [82,81,79,81,74,74,79,67,69,70,72,74,75,77,75,74,72,74,75,74,72,70,72,74,72,70,72,69],
    [5,4,3,4,1,1,5,1,2,3,4,5,3,4,3,2,1,2,3,2,1,2,3,4,3,2,3,1],
    [1,1,1,1,1,1,1,0.5,0.5,0.5,0.5,3,1,0.5,0.5,0.5,0.5,1,0.5,0.5,0.5,0.5,1,0.5,0.5,0.5,0.5,3],
    [], [], MUTOPIA + "BachJS/BWVAnh115/anna-magdalena-05/anna-magdalena-05.ly"),
  // Public Domain; Mutopia typesetter: Allen Garvin.
  // voiceone; transpose 0 semitones; source SHA-256 8fbbf2f3f69454c29e6171c046d07c46ee7c44a9f47653e10811fc4b9890a020
  new Lesson("Minuet in G (Anh. 116)", "Anna Magdalena Bach notebook", 3, 2, "G major", 3, 4, 88,
    [67,71,74,79,69,78,79,67,67,67,71,74,79,69,78,79,67,67,76,76,76,79,74,74,74,79,72,74,72,71,72,69],
    [1,2,3,5,1,4,5,1,1,1,2,3,5,1,4,5,1,1,4,4,4,5,3,3,3,5,2,3,2,1,2,1],
    [0.5,0.5,0.5,0.5,0.5,0.5,1,1,1,0.5,0.5,0.5,0.5,0.5,0.5,1,1,1,1,1,0.5,0.5,1,1,0.5,0.5,1,0.5,0.5,0.5,0.5,3],
    [], [], MUTOPIA + "BachJS/BWVAnh116/anna-magdalena-07/anna-magdalena-07.ly"),
  // Public Domain; Mutopia typesetter: Allen Garvin.
  // voiceone; transpose 0 semitones; source SHA-256 36c105c4c696aac3bbdc63f444cd05d6ca3e97f438eef21575e15669aa31b6aa
  new Lesson("Musette in D", "Anna Magdalena Bach notebook", 3, 2, "D major", 2, 4, 88,
    [81,79,78,76,74,81,79,78,76,74,66,67,69,67,66,64,69,66,62],
    [5,4,3,2,1,5,4,3,2,1,1,2,3,2,1,2,5,3,1],
    [1,0.25,0.25,0.25,0.25,1,0.25,0.25,0.25,0.25,0.25,0.25,0.5,0.5,0.5,0.5,0.5,0.5,0.5],
    [], [], MUTOPIA + "BachJS/BWVAnh126/anna-magdalena-22/anna-magdalena-22.ly"),
  // Public Domain; Mutopia typesetter: Evin Robertson.
  // top; transpose 0 semitones; source SHA-256 420a52244e9fbe106dd33ba2cac84414fd66e0d01c6d472205bad39678d4ce04
  new Lesson("Gymnopedie No. 1", "Erik Satie", 3, 1, "B minor", 3, 4, 60,
    [78,81,79,78,73,71,73,74,69,66],
    [3,5,4,3,1,2,3,4,2,1],
    [1,1,1,1,1,1,1,1,3,12],
    [], [], MUTOPIA + "SatieE/gymnopedie_1/gymnopedie_1.ly"),
  // Public Domain; Mutopia typesetter: Evin Robertson.
  // top; transpose 0 semitones; source SHA-256 54182340c4be942ea2ebbe2fcefd0734bfb29d02bd76672fd3751c8600c27d8c
  new Lesson("Gymnopedie No. 2", "Erik Satie", 3, 1, "A minor", 3, 4, 60,
    [79,81,79,77,76,77,79,74,79,81,79,77,76,77,79,74,72],
    [4,5,4,3,2,3,4,1,4,5,4,3,2,3,4,2,1],
    [3,1,1,1,1,1,1,3,3,1,1,1,1,1,1,1,2],
    [], [], MUTOPIA + "SatieE/gymnopedie_2/gymnopedie_2.ly"),
  // Public Domain; Mutopia typesetter: Evin Robertson.
  // top; transpose 0 semitones; source SHA-256 d0b774aee7df39627d57b66c1269ec3a10e89f9fe3d271df9f4d5e3c082d9001
  new Lesson("Gymnopedie No. 3", "Erik Satie", 3, 1, "A minor", 3, 4, 60,
    [81,79,77,76,74,76,77,76,74,72,76],
    [5,4,3,2,1,2,3,2,1,2,3],
    [3,1,1,1,1,1,1,1,1,1,3],
    [], [], MUTOPIA + "SatieE/gymnopedie_3/gymnopedie_3.ly"),
  // Public Domain; Mutopia typesetter: David McNamara.
  // melodyAHead; transpose 0 semitones; source SHA-256 b65b68630d04552ff7d6f56d0282a219feba407f1038ad544eb4f7d716876628
  new Lesson("Old French Song", "Pyotr Ilyich Tchaikovsky", 3, 1, "G minor", 2, 4, 76,
    [62,67,69,70,72,74,74,72,74,75,72,74,74,72,74,75,72,74,75,74,72,70,69,67],
    [1,2,3,4,1,3,3,2,3,4,2,3,3,2,3,4,2,3,4,3,2,1,2,1],
    [0.5,0.5,0.5,0.5,0.5,1.5,0.5,0.5,0.5,0.5,0.5,1.5,0.5,0.5,0.5,0.5,0.5,0.5,0.25,0.25,0.5,0.5,1.75,0.25],
    [], [], MUTOPIA + "TchaikovskyPI/O39/16OldFrenchSong/16OldFrenchSong.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // vOne; transpose 0 semitones; source SHA-256 7d90a5ee981da904c1dc9aeb4ab4d25575818c8552f6dff47f98b73fde571342
  new Lesson("Innocent Candor", "Friedrich Burgmuller", 3, 2, "C major", 4, 4, 80,
    [79,76,74,72,79,76,74,72,84,81,79,77,84,81,79,77,79,76,74,72,71,72,76,77,79,76,74,72,71,72,74,76],
    [5,3,2,1,5,3,2,1,5,3,2,1,5,3,2,1,5,3,2,1,2,1,3,4,5,3,2,1,2,1,2,3],
    [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-01/25EF-01.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // MD; transpose 0 semitones; source SHA-256 9ee203a6c2059700b10d45a7a1fd7a122803793af9a2e328d634bee538819a94
  new Lesson("Arabesque", "Friedrich Burgmuller", 3, 2, "A minor", 2, 4, 88,
    [69,71,72,71,69,69,71,72,74,76,74,76,77,79,81,81,83,84,86,88],
    [1,2,3,2,1,1,2,3,4,5,1,2,3,4,5,1,2,3,4,5],
    [0.25,0.25,0.25,0.25,1,0.25,0.25,0.25,0.25,1,0.25,0.25,0.25,0.25,1,0.25,0.25,0.25,0.25,0.5],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-02/25EF-02.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // MD; transpose 0 semitones; source SHA-256 be3b90be0fcfe7d92e34ef189cb633f7007e38ea8d5f290e4c3e5a988f097c81
  new Lesson("Pastorale", "Friedrich Burgmuller", 3, 2, "G major", 6, 8, 80,
    [67,71,72,74,71,76,74,79,76,74,71,72,74,71,74,76,74,79,74,71,69,72,69,71,67,67,71,72],
    [1,2,3,4,1,3,2,5,3,2,1,2,3,1,3,4,2,5,3,1,2,4,2,3,1,1,2,3],
    [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,1.5,0.5,0.5,0.5,1.5,0.5,0.5,0.5,1.5,0.5,0.5,0.5,1.5,0.5,0.5,0.5],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-03/25EF-03.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose 0 semitones; source SHA-256 97c25bd304d8972a6aca488d2f61b52b4cb229c17bcec14b5922bb4d92f6aeee
  new Lesson("A Little Gathering", "Friedrich Burgmuller", 3, 2, "C major", 4, 4, 84,
    [77,76,74,72,71,69,67,65,64,77,76,74,72,71,69,67,65,64],
    [5,4,3,2,1,3,2,1,3,5,4,3,2,1,3,2,1,3],
    [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,4,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,1],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-04/25EF-04.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose 0 semitones; source SHA-256 f19c5f5986cfc75d56263a4cab98eac7d3927c10bce75917766e49351280286a
  new Lesson("Innocence", "Friedrich Burgmuller", 3, 3, "F major", 3, 4, 72,
    [81,79,77,76,77,76,74,72,74,72,70,69,72,70,70,79,77,76,74,72,74,76,77,79,81,82,84,82,81,81],
    [4,3,2,1,4,3,2,1,4,3,2,1,3,2,2,5,4,3,2,1,2,3,1,2,3,4,5,4,3,3],
    [0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.5,0.5,2,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.5,0.5,1],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-05/25EF-05.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose 0 semitones; source SHA-256 e3f05f6bd21543333f1843d1f024f721bba34f63699de71e09def1d0d6f5ad61
  new Lesson("Progress", "Friedrich Burgmuller", 3, 3, "C major", 4, 4, 72,
    [64,65,67,69,71,72,74,76,71,72,69,67,69,71,72,74,76,77,79,78,79,76,77,86,74,83,71,79,77,74,76],
    [1,2,3,1,2,3,4,5,2,4,2,1,2,3,1,2,3,4,5,4,5,3,1,5,1,5,1,4,3,2,1],
    [0.5,0.25,0.25,0.25,0.25,0.25,0.25,0.5,0.5,0.5,0.5,0.5,0.25,0.25,0.25,0.25,0.25,0.25,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,4],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-06/25EF-06.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose 0 semitones; source SHA-256 c53e24fd09d82f95c34684bbcc51e5a59378d0263a2ee92a6f8e1ab997c1ce18
  new Lesson("The Clear Stream", "Friedrich Burgmuller", 3, 2, "G major", 4, 4, 64,
    [59,67,62,59,67,62,60,69,62,57,66,62,59,67,62,59,67,62,62,71,67,67,74,71],
    [1,5,3,1,5,3,2,5,3,1,4,2,1,5,3,1,5,3,1,5,3,1,5,3],
    [0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333,0.333333333],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-07/25EF-07.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose 0 semitones; source SHA-256 67a2b204b7a4757522fcdc67adf368df923cd2f9208da4bde7548b3365f73f7a
  new Lesson("Gracefulness", "Friedrich Burgmuller", 3, 3, "F major", 3, 4, 64,
    [72,74,72,71,72,77,79,77,76,77,81,72,74,72,71,72,79,81,79,78,79,82],
    [3,4,3,2,1,3,4,3,2,1,3,3,4,3,2,1,3,4,3,2,1,5],
    [0.5,0.125,0.125,0.125,0.125,0.5,0.125,0.125,0.125,0.125,1,0.5,0.125,0.125,0.125,0.125,0.5,0.125,0.125,0.125,0.125,0.5],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-08/25EF-08.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose 0 semitones; source SHA-256 dffb7f9c2d2b3f4a1fbcc24c1e6854909143188e5bea4f96be06f75599feaa89
  new Lesson("The Hunt", "Friedrich Burgmuller", 3, 2, "C major", 6, 8, 96,
    [79,67,67,79,67,67,79,67,67,79,67,67,79,67,67,79,67,67,79,77,74,71,69,67],
    [5,2,1,5,2,1,5,2,1,5,2,1,5,2,1,5,2,1,5,4,3,1,2,1],
    [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-09/25EF-09.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose -12 semitones; source SHA-256 facd4daa13d8b44afb23aa69c21149d4249f2befa99cb83b449b8254a66327f9
  new Lesson("Tender Flower", "Friedrich Burgmuller", 3, 2, "D major", 4, 4, 72,
    [50,52,54,57,57,62,62,66,66,64,61,57,69,69,78,78,74,74,69,69,66,66,64,61,57,69],
    [1,3,2,4,1,3,2,4,4,3,2,1,5,1,4,4,3,3,1,4,2,4,3,2,1,5],
    [0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,2,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,2],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-10/25EF-10.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose -12 semitones; source SHA-256 d77672593d1a66f323c9f4a615ebdb9a62ca927c07813acd08b2a2ecabf11fd5
  new Lesson("The Wagtail", "Friedrich Burgmuller", 3, 2, "C major", 2, 4, 80,
    [79,76,72,76,72,67,72,67,64,67,64,60,66,65,64,69,62,67],
    [5,3,1,3,1,5,1,5,3,5,3,1,3,2,1,4,2,5],
    [0.25,0.25,0.5,0.25,0.25,0.5,0.25,0.25,0.5,0.25,0.25,0.5,1,1,1,1,2,1],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-11/25EF-11.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose 0 semitones; source SHA-256 e7fdda1ded2cfc8e25645a5bb5235e60edbebb6ba15ba868405dfb61f675c1c6
  new Lesson("Farewell", "Friedrich Burgmuller", 3, 2, "C major", 4, 4, 76,
    [76,77,76,76,74,74,76,74,74,72,76,75,76,86,84,83,81,80,77,76,74,72,71,70,71,76,74],
    [2,3,2,3,2,2,3,2,3,1,3,2,1,5,4,3,1,3,2,1,3,2,1,2,1,5,4],
    [0.5,0.5,0.5,1,1.5,0.5,0.5,0.5,1,1.5,0.5,0.5,0.5,1.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-12/25EF-12.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose 0 semitones; source SHA-256 54f46cb419baa9a7b11faa1bc271450fa811474c883a77ef315aa9792e124066
  new Lesson("Consolation", "Friedrich Burgmuller", 3, 2, "C major", 4, 4, 72,
    [74,76,74,76,74,76,74,72,74,72,74,72,74,72,77,79,77,79,77,79,77,76,77,76,77,76,77,76],
    [4,5,4,5,4,5,4,3,4,3,4,3,4,3,4,5,4,5,4,5,4,3,4,3,4,3,4,3],
    [0.5,0.5,0.5,0.5,0.5,0.5,1,0.5,0.5,0.5,0.5,0.5,0.5,1,0.5,0.5,0.5,0.5,0.5,0.5,1,0.5,0.5,0.5,0.5,0.5,0.5,0.5],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-13/25EF-13.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose 0 semitones; source SHA-256 a1d4901914dbcc31ef2e2251b816933edaf5018a0d3ced225496633e2ad8a37c
  new Lesson("Gentle Lament", "Friedrich Burgmuller", 3, 2, "G minor", 4, 4, 72,
    [74,72,70,69,67,74,79,77,75,75,74,72,74],
    [5,4,3,2,1,2,5,4,3,3,2,1,2],
    [2.5,0.5,0.5,0.5,2.5,0.5,0.5,0.5,2.5,0.5,0.5,0.5,2.5],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-16/25EF-16.ly"),
  // Public Domain; Mutopia typesetter: Bas Wassink.
  // VoiceI; transpose 0 semitones; source SHA-256 19798a410dc258d8733d7428d8d9a1381c942e3609988f86fa1b646ad3f6a681
  new Lesson("Restlessness", "Friedrich Burgmuller", 3, 3, "E minor", 2, 4, 80,
    [79,78,76,76,74,72,71,70,71,71,72,71,79,78,76,76,74,72,71,70,71,71,72,71],
    [3,2,1,3,2,1,3,2,3,3,4,3,3,2,1,3,2,1,3,2,3,3,4,3],
    [0.25,0.25,0.5,0.25,0.25,0.5,0.25,0.25,0.5,0.25,0.25,0.5,0.25,0.25,0.5,0.25,0.25,0.5,0.25,0.25,0.5,0.25,0.25,0.25],
    [], [], MUTOPIA + "BurgmullerJFF/O100/25EF-18/25EF-18.ly"),
  // END GENERATED MUTOPIA EXCERPTS
];
