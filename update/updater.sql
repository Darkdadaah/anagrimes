DROP TABLE IF EXISTS articles_temp, mots_temp, langues_temp ;
SELECT '- Potential temporary tables dropped' AS '' ;


CREATE TABLE articles_temp LIKE articles;

SELECT '- Filling the temporary ARTICLES table...' AS '' ;

LOAD DATA LOCAL INFILE '/home/darkdadaah/data/tables/fr-wikt_current_articles.csv'
INTO TABLE articles_temp FIELDS
        TERMINATED BY ','
        ENCLOSED BY '"' LINES
        TERMINATED BY '\n'
(titre, r_titre, titre_plat, r_titre_plat, transcrit_plat, r_transcrit_plat, anagramme_id);

CREATE TABLE mots_temp LIKE mots;

LOAD DATA LOCAL INFILE '/home/darkdadaah/data/tables/fr-wikt_current_mots.csv'
INTO TABLE mots_temp FIELDS
	TERMINATED BY ','
	ENCLOSED BY '"' LINES
	TERMINATED BY '\n'
(titre,langue,type,pron,pron_simple,r_pron_simple,num,flex,loc,gent,rand);

SELECT '- Filling the temporary LANGUAGE table...' AS '' ;


CREATE TABLE langues_temp LIKE langues;

LOAD DATA LOCAL INFILE '/home/darkdadaah/data/tables/fr-wikt_current_langues.csv'
INTO TABLE langues_temp FIELDS
	TERMINATED BY ','
	ENCLOSED BY '"' LINES
	TERMINATED BY '\n'
(langue,num,num_min);


SELECT '- Replace the old tables by the new ones' AS '' ;

RENAME TABLE    articles TO articles_old,
                articles_temp TO articles,
		mots TO mots_old,
                mots_temp TO mots,
		langues TO langues_old,
                langues_temp TO langues ;

SELECT '- Drop the old tables' AS '' ;
DROP TABLE articles_old, mots_old, langues_old ;

SELECT 'DONE' AS '' ;
