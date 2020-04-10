# Voter-Tokens
A Ruby tool to generate tokens for voters based on delegate counts for online elections
and then validate those tokens when counting votes

## How-To

### Requirements
 - [Ruby](https://www.ruby-lang.org/en/)
 - [GNU Make](https://www.gnu.org/software/make/) (optional but recommended)

### Usage
Clone this repo from Github

#### Installation
```
git clone https://github.com/hbiede/Voter-Tokens.git
cd Voter-Tokens
```

#### Generate Tokens
Update data/delegates.csv with the names of groups/individuals and how many tokens should
be generated for each. The header for the column with the group/individual must be school,
chapter, organization, or name. The header for the column with the number of votes must be
delegate, vote, or voter. Plurals of the approved headers also work (eg. voters is
allowed).

##### PDFs
To generate PDFs of your organizations' passwords (one per organization), modify
pdfs/voting.tex. This file must be valid LaTeX. PDFs can be disabled by modifying
gen\_tokens.rb so that generate\_pdfs = false and reenabled by returning it to true.

##### Run Token Generation
```
ruby gen_tokens.rb data/delegates.csv data/tokens.csv
```

#### Parse Ballots
Download the CSV of your ballots to data/votes.csv and then run the following command:
```
ruby vote_parser.rb data/votes.csv data/tokens.csv
```

##### Parse Ballots from Google Sheets
If your ballots are stored on the first sheet of a Google Sheet in range B1:G, you can
download and parse votes all in one command:
```
make URL=https://docs.google.com/spreadsheets/d/DOCUMENT_ID/export?exportFormat=csv&range=B1:G
```
**Note: you must change DOCUMENT_ID to the alphanumeric code in the link to your Google
Sheet. The Sheet *must* be viewable by anyone.**