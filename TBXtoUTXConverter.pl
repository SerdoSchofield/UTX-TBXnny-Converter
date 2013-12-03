#!usr/bin/perl

#Reads in TBX-Min and Writes out UTX 1.11


use 5.016;
use strict;
use warnings;
use DateTime;
use TBX::Min;
use open ':encoding(utf8)', ':std';

@ARGV == 2 or die 'usage: TBX-UTX-Converter.pl <tbx_path> <output_path>';

open my $in, '<', $ARGV[0]
		or die "cannot open $ARGV[0] for reading\n";
open OUT, '>', $ARGV[1]
		or die "Please specify an Output file";

sub import_tbx {  #really only checks for validity of TBX file
	@_ = <$in>;
	die "Not a TBX-Min file" unless ($_[1] =~ /tbx-min/i);
}

sub export_utx {
	my $TBX = TBX::Min->new_from_xml($ARGV[0]);
	my ($source_lang, $target_lang, $creator, $license, $directionality, $DictID, 
		$description, $concepts); #because TBX-Min supports multiple subject fields and UTX does not, subject_field cannot be included here
	#note that in UTX 1.11, $source_lang, $target_lang,$creator, and $license are required
	
	my $timestamp = DateTime->now()->iso8601();
	
	#Get values from input
	$source_lang = $TBX->source_lang;
	$target_lang = $TBX->target_lang;
	$creator = "  copyright: ".$TBX->creator.";";
	$license = "  license: ".$TBX->license.";";
	$directionality = "  ".$TBX->directionality.";" if (defined $TBX->directionality);
	$DictID = "  Dictionary ID: ".$TBX->id.";" if (defined $TBX->id);
	$description = "description: ".$TBX->description.";" if (defined $TBX->description);
	$concepts = $TBX->concepts;
	
	#print header
	print OUT "#UTX 1.11;  $source_lang/$target_lang;  $timestamp;$creator$license$directionality$DictID\n";
	print OUT "#$description\n" if (defined $description); #print middle of header if necessary
	print OUT "#src	tgt	src:pos";  #print necessary values of final line of Header
	
	my @output;
	my ($tgt_pos_exists, $status_exists, $customer_exists, $src_note_exists, $tgt_note_exists) = 0;
	
	foreach my $concept (@$concepts){
		my ($concept_id, $lang_groups, $src_term, $tgt_term, $src_pos, $tgt_pos, $src_note, $tgt_note, $customer, $status);
		(defined $concept->id) ? ($concept_id = "\t".$concept->id) : 0; #($concept_id = "\t-");
		$lang_groups = $concept->lang_groups;
		
		foreach my $lang_group (@$lang_groups){
			my $term_groups = $lang_group->term_groups;
			my $code = $lang_group->code;
			
			foreach my $term_group (@$term_groups){
				if ($code eq $source_lang){
					$src_term = $term_group->term."\t";
					
					my $value = $term_group->part_of_speech;
					(defined $value && $value =~ /noun|properNoun|verb|adjective|adverb/i) ? ($src_pos = $value) : ($src_pos = "-");
					
					if (defined $term_group->note){
						($src_note = "\t".$term_group->note);
						$src_note_exists = 1;
					}
				}
				elsif ($code eq $target_lang){
					$tgt_term = $term_group->term."\t";
					
					my $value = $term_group->part_of_speech;
					if (defined $value && $value =~ /noun|properNoun|verb|adjective|adverb|sentece/i){ #technically sentence should never exist in current TBX-Min
						$tgt_pos = "\t".$value;
						$tgt_pos_exists = 1;
					}
					
					if (defined $term_group->note){
						($tgt_note = "\t".$term_group->note);
						$tgt_note_exists = 1;
					}
				}
				
				if (defined $term_group->customer){
					($customer = "\t".$term_group->customer);
					$customer_exists = 1;
				}
				if (defined $term_group->status){
					
					my $value = $term_group->status;
					$status = $value if $value =~ /admitted|preferred|notRecommended|obsolete/i;
					
					$status = "provisional" if $status =~ /admitted/i;
					$status = "approved" if $status =~ /preferred/i;
					$status = "non-standard" if $status =~ /notRecommended/i;
					$status = "forbidden" if $status =~ /obsolete/i;
					
					$status = "\t".$status if defined $status;
					$status_exists = 1;
				}
				
				if (defined $src_term && defined $tgt_term){
					my @output_line = ($src_term, $tgt_term, $src_pos, $tgt_pos, $status, $customer, $src_note, $tgt_note, $concept_id);
					push @output, \@output_line;
					#~ print_out($src_term, $tgt_term, $src_pos, $tgt_pos, $status, $customer, $note, $concept_id);
				}
			}
		}
	}
	return [$tgt_pos_exists, $status_exists, $customer_exists, $src_note_exists, $tgt_note_exists, @output];
}

sub print_out { #accepts $exists, and @output
	my $args = shift;
	my ($tgt_pos_exists, $status_exists, $customer_exists, $src_note_exists, $tgt_note_exists, @output) = @$args;
	
	print OUT "\ttgt:pos" if ($tgt_pos_exists);
	print OUT "\tterm status" if ($status_exists);
	print OUT "\tcustomer" if ($customer_exists);
	print OUT "\tsrc:comment" if ($src_note_exists);
	print OUT "\ttgt:comment" if ($tgt_note_exists);
	
	foreach my $output_line_ref (@output) {
				
		my ($src_term, $tgt_term, $src_pos, $tgt_pos, $status, $customer, $src_note, $tgt_note, $concept_id) = @$output_line_ref;
		
		if (defined $src_term && defined $tgt_term){
			print OUT "\n$src_term$tgt_term$src_pos";
			
			if ($tgt_pos_exists){ (defined $tgt_pos) ? (print OUT "$tgt_pos") : (print OUT "\t-") }
			if ($status_exists){ (defined $status) ? (print OUT "$status") : (print OUT "\t-") }
			if ($customer_exists){ (defined $customer) ? (print OUT "$customer") : (print OUT "\t-") }
			if ($src_note_exists){ (defined $src_note) ? (print OUT "$src_note") : (print OUT "\t-") }
			if ($tgt_note_exists){ (defined $tgt_note) ? (print OUT "$tgt_note") : (print OUT "\t-") }
		}
	}
}

print_out(export_utx(import_tbx()));